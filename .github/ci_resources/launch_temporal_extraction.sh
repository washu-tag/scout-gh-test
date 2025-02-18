#!/bin/bash

all_dates=$(find tests/staging_test_data/hl7 -name '*.log' | xargs -L 1 basename | cut -c1-8 | sort | paste -sd ",")
echo "Submitting dates to temporal: $all_dates"
sudo kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow start --task-queue ingest-hl7-log --type IngestHl7LogWorkflow --input '{"deltaLakePath":"s3://lake/orchestration/delta/test_data", "hl7OutputPath":"s3://lake/orchestration/hl7", "scratchSpaceRootPath":"s3://lake/orchestration/scratch", "logsRootPath": "/hl7logs", "date": "'$all_dates'"}'

max_wait=60
for ((i = 0; i <= max_wait; ++i)); do
    if sudo kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow list -o json | jq '[.[] | select(.taskQueue == "ingest-hl7-log")] | all(.[]; .status == "WORKFLOW_EXECUTION_STATUS_COMPLETED")' -e > /dev/null; then
        echo "All workflows completed as expected"
        sudo kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow list -o json
        sleep 60s
        sudo kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow list -o json
        exit 0
    else
        echo "Not all workflows completed, waiting and trying again..."
    fi

    sleep 1s
    if [[ i -eq max_wait ]]; then
        echo "DEBUGGING:"
        sudo kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow list -o json | jq -r '.[] | "\(.execution.workflowId) \(.execution.runId)"' | while read workflowId runId; do
            echo "Workflow id $workflowId and run id $runId"
            sudo kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow show --workflow-id $workflowId --run-id $runId
        done
        exit 25
    fi
done