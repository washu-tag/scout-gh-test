#!/bin/bash

for logdate in $(find tests/staging_test_data/hl7/1999 -name '*.log' | xargs -L 1 basename | cut -c1-8 | sort)
do
    echo "Sending date $logdate to temporal..."
    sudo kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow start --task-queue ingest-hl7-log --type IngestHl7LogWorkflow --input '{"deltaLakePath":"s3://test/orchestration/delta/test_data", "hl7OutputPath":"s3://test/orchestration/hl7", "scratchSpaceRootPath":"s3://test/orchestration/scratch", "logsRootPath": "/hl7logs", "date": "'$logdate'"}';
done

max_wait=50
for ((i = 0; i <= max_wait; ++i)); do
    if sudo kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow list -o json | jq '[.[] | select(.taskQueue == "ingest-hl7-log")] | any(.[]; .status == "WORKFLOW_EXECUTION_STATUS_COMPLETED")' -e > /dev/null; then
        echo "All workflows completed as expected"
        exit 0
    else
        echo "Not all workflows completed, waiting and trying again..."
    fi

    sleep 1s
    if [[ i -eq max_wait ]]; then
        sudo kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow list -o json
        sudo kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow list -o json | jq -r '.[] | "\(.execution.workflowId) \(.execution.runId)"' | while read workflowId runId; do
            kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow show --workflow-id $workflowId --run-id $runId
        done
        exit 25
    fi
done