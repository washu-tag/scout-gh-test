#!/bin/bash

for logdate in $(find tests/staging_test_data/hl7 -name '*.log' | xargs -L 1 basename | cut -c1-8 | sort)
do
    echo "Sending date $logdate to temporal..."
    sudo kubectl exec -n temporal -i service/temporal-admintools -- temporal workflow start --task-queue ingest-hl7-log --type IngestHl7LogWorkflow --input '{"deltaLakePath":"s3://test/orchestration/delta/test_data", "hl7OutputPath":"s3://test/orchestration/hl7", "scratchSpaceRootPath":"s3://test/orchestration/scratch", "logsRootPath": "/hl7logs", "date": "'$logdate'"}';
done