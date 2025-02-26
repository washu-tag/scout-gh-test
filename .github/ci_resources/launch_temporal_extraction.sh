#!/bin/bash

max_wait=300
for logdate in $(find tests/staging_test_data/hl7 -name '*.log' | xargs -L 1 basename | cut -c1-8 | sort); do
    echo "Submitting date to temporal: $logdate"
    read workflow_id run_id < <(echo $(kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow start --task-queue ingest-hl7-log --type IngestHl7LogWorkflow --input '{"deltaLakePath":"s3://lake/orchestration/delta/test_data", "hl7OutputPath":"s3://lake/orchestration/hl7", "scratchSpaceRootPath":"s3://lake/orchestration/scratch", "logsRootPath": "/hl7logs", "date": "'$logdate'"}' -o json | jq -r '.workflowId, .jobId'))
    for ((i = 0; i <= max_wait; ++i)); do
        kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow show --workflow-id $workflow_id --run-id $run_id
        break;
    done
done
