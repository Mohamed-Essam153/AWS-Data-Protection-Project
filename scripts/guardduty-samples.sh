#!/usr/bin/env bash
# Generates GuardDuty SAMPLE findings for S3 so we can walk through the response steps.
# They are marked [SAMPLE] in the console - say so in the report, they are not incidents.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
require aws jq
load_config
load_outputs
[[ "$GUARDDUTY_ENABLED" == "true" ]] || die "GuardDuty is off. Set ENABLE_GUARDDUTY=true and re-run deploy.sh"

DET=$(stack_output dp-lab-detection DetectorId)
aws guardduty create-sample-findings --detector-id "$DET" --finding-types \
  Policy:S3/BucketBlockPublicAccessDisabled \
  Exfiltration:S3/AnomalousBehavior \
  Discovery:S3/MaliciousIPCaller \
  UnauthorizedAccess:S3/TorIPCaller

sleep 5
aws guardduty list-findings --detector-id "$DET" \
  --finding-criteria '{"Criterion":{"resource.resourceType":{"Eq":["S3Bucket"]}}}' \
  --query FindingIds --output json \
  | jq -r '.[]' | head -20 \
  | xargs aws guardduty get-findings --detector-id "$DET" --query 'Findings[].[Type,Severity,Title]' \
      --output table --finding-ids
