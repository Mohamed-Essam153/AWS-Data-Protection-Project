#!/usr/bin/env bash
# Prints Macie findings as a table and saves a redacted markdown copy to evidence/.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
require aws jq
load_config

IDS=$(aws macie2 list-findings --max-results 50 --query findingIds --output json)
[[ "$(echo "$IDS" | jq length)" -gt 0 ]] || die "No findings yet - is the job finished?"

OUT="$REPO_ROOT/evidence/macie-findings-$(date +%Y%m%d-%H%M).md"
{
  echo "# Macie findings ($(date -u +%Y-%m-%dT%H:%MZ))"
  echo
  echo "| Object | Finding type | Severity | Detections |"
  echo "|---|---|---|---|"
  mapfile -t ID_LIST < <(echo "$IDS" | jq -r '.[]')
  aws macie2 get-findings --finding-ids "${ID_LIST[@]}" --output json \
    | jq -r '.findings[] | "| \(.resourcesAffected.s3Object.key) | \(.type) | \(.severity.description) | \([.classificationDetails.result.sensitiveData[]?.detections[]? | "\(.type) x\(.count)"] + [.classificationDetails.result.customDataIdentifiers.detections[]? | "\(.name) x\(.count)"] | join(", ")) |"'
} | redact | tee "$OUT"

log "Saved $OUT"
