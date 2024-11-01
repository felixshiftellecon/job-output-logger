# CircleCI Job Logger Orb

Use this orb to run the `gather_job_logs` job as the last job in a workflow to gather all the step outputs from previously run jobs in that workflow.

Alternatively, the `gather_job_logs` commands can be used in the last job in a workflow if needed.

## Storing Job Logs

By default the job and command:
- Store the job logs as an artifact in CircleCI by having the `store_artifact` parameter set to `true`
- Send the job logs to AWS S3 by having the `send_to_aws` parameter set to `true`

To change where job logs are being sent, change the applicable parameters above to false. If using the command, include your own steps as necessary after the command. If using the job, add your own [post-step](https://circleci.com/docs/configuration-reference/#pre-steps-and-post-steps) after the job.

## Caveats

This job/command will gather step outputs from all jobs previously run in the workflow but it will **NOT** gather logs from the `gather_job_logs` job or a job that uses the `gather_job_logs` step. Step outputs are not available until jobs have completed running.

This job/command must be run last in the workflow.
