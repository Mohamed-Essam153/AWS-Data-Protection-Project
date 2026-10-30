#!/usr/bin/env bash
# Starts a one-time Macie job over the data bucket (100% sampling, recommended managed
# identifiers + our EmployeeID identifier). Needs ENABLE_MACIE=true and a deploy.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
require aws jq
load_config
load_outputs

[[ "$MACIE_ENABLED" == "true" ]] || die "Macie is off. Set ENABLE_MACIE=true in config.env and re-run deploy.sh"

ACCOUNT=$(account_id)
CDI=$(stack_output dp-lab-detection EmployeeIdIdentifierId)
NAME="dp-lab-macie-job-$(date +%Y%m%d-%H%M)"

JOB_ID=$(aws macie2 create-classification-job \
  --job-type ONE_TIME \
  --name "$NAME" \
  --sampling-percentage 100 \
  --managed-data-identifier-selector RECOMMENDED \
  --custom-data-identifier-ids "$CDI" \
  --s3-job-definition "{\"bucketDefinitions\":[{\"accountId\":\"$ACCOUNT\",\"buckets\":[\"$DATA_BUCKET\"]}]}" \
  --query jobId --output text)

log "Started $NAME ($JOB_ID). It usually takes 10-20 minutes."
log "Check status: aws macie2 describe-classification-job --job-id $JOB_ID --query jobStatus"
log "Then list findings: ./scripts/macie-findings.sh"
