#!/bin/bash

WORKFLOW_ID=$CIRCLE_WORKFLOW_ID
VCS_TYPE=$(echo $CIRCLE_BUILD_URL | cut -d'/' -f4)

if [[ "$VCS_TYPE" == "gh" ]]; then
  VCS_TYPE="github"
elif [[ "$VCS_TYPE" == "bb" ]]; then
  VCS_TYPE="bitbucket"
fi

USERNAME=$CIRCLE_PROJECT_USERNAME
PROJECT=$CIRCLE_PROJECT_REPONAME

echo "Gathering job_numbers for workflow: ${CIRCLE_WORKFLOW_ID}"

JOBS=$(curl https://circleci.com/api/v2/workflow/${WORKFLOW_ID}/job -H "Circle-Token: ${CIRCLE_TOKEN}")
JOB_NUMBERS=$(echo $JOBS | jq -r '.items[].job_number')

JSON_OUTPUT="[]"
JSON_OUTPUT_TEMPFILE="[]"

echo "Creating build log folder"

LOG_PATH=$(circleci env subst "${PARAM_LOG_PATH}")

mkdir -p ${LOG_PATH:-job_logs}

echo "Accessing build data for job numbers: ${JOB_NUMBERS}"

for JOB_NUMBER in $JOB_NUMBERS
do
  echo "Gathering build logs for job: ${JOB_NUMBER}"

  JOB_OUTPUT=$(curl https://circleci.com/api/v1.1/project/${VCS_TYPE}/${USERNAME}/${PROJECT}/${JOB_NUMBER} -H "Circle-Token: ${CIRCLE_TOKEN}") || { echo "Failed to fetch job output"; exit 1; }
  
  echo "Job Output for ${JOB_NUMBER}: \n ${JOB_OUTPUT}"

  JOB_JSON_OUTPUT="[]"

  while read -r STEP; do
    STEP_NAME=$(echo $STEP | jq -r '.name') || { echo "Failed to parse step name"; exit 1; }
    OUTPUT_URL=$(echo $STEP | jq -r '.actions[].output_url') || { echo "Failed to parse output URL"; exit 1; }

    echo "Step Name: ${STEP_NAME}"
    echo "Build Log URL: ${OUTPUT_URL}"

    if [ -z "$OUTPUT_URL" ] || [ "$OUTPUT_URL" == "null" ]; then
      echo "Output URL not available for this step. It might be the last step in the last job and hasn't completed yet."
      JOB_JSON_OUTPUT=$(echo $JOB_JSON_OUTPUT | jq --arg stepName "$STEP_NAME" '. + [{"stepName": $stepName, "outputUrl": "Output URL not available for this step. It might be the last step in the last job and hasnt completed yet", "logs": "Logs not available for this step. It might be the last step in the last job and hasnt completed yet"}]')
      echo "Adding step name to build logs: \n ${JOB_JSON_OUTPUT}"
    else
      LOGS=$(curl $OUTPUT_URL -H "Circle-Token: ${CIRCLE_TOKEN}") || { echo "Failed to fetch logs"; exit 1; }
      echo "Step logs: ${LOGS}"
      JOB_JSON_OUTPUT=$(echo $JOB_JSON_OUTPUT | jq --arg stepName "$STEP_NAME" --arg outputUrl "$OUTPUT_URL" --arg logs "$LOGS" '. + [{"stepName": $stepName, "outputUrl": $outputUrl, "logs": $logs}]') || { echo "Failed to update JSON output"; exit 1; }
      echo "Adding step logs to build logs: \n ${JOB_JSON_OUTPUT}"
    fi
  done < <(echo $JOB_OUTPUT | jq -c '.steps[]')

  JSON_OUTPUT=$(echo $JSON_OUTPUT | jq --arg jobNumber "$JOB_NUMBER" --argjson jobData "$JOB_JSON_OUTPUT" '. + [{"jobNumber": $jobNumber, "steps": $jobData}]')
  echo "Gathered build logs for job: ${JOB_NUMBER}"
done

echo $JSON_OUTPUT > $JSON_OUTPUT_TEMPFILE

echo "Compiling build logs in directory: ${LOG_PATH:-job_logs}"

jq -s '.' $JSON_OUTPUT_TEMPFILE > ${LOG_PATH:-job_logs}/workflow_${CIRCLE_WORKFLOW_ID}_jobs_logs.json