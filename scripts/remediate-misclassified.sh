#!/usr/bin/env bash
# The fix for the Macie finding on internal/notes-export.csv (card numbers in an
# "Internal" file): move it to restricted/, re-tag it, remove the old versions under
# internal/ and show who read it while it sat in the wrong place.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
require aws jq
load_config
load_outputs

SRC=internal/notes-export.csv
DST=restricted/notes-export.csv

aws s3api head-object --bucket "$DATA_BUCKET" --key "$SRC" >/dev/null 2>&1 \
  || die "$SRC is not there (already remediated?)"

log "Moving $SRC -> $DST"
aws s3 mv "s3://$DATA_BUCKET/$SRC" "s3://$DATA_BUCKET/$DST" --only-show-errors
aws s3api put-object-tagging --bucket "$DATA_BUCKET" --key "$DST" \
  --tagging 'TagSet=[{Key=DataClassification,Value=Restricted}]'

log "Removing old versions left under $SRC"
aws s3api list-object-versions --bucket "$DATA_BUCKET" --prefix "$SRC" --output json \
  | jq -c '{Objects: ([.Versions[]?, .DeleteMarkers[]?] | map({Key, VersionId})), Quiet: true}' \
  > /tmp/dp-lab-del.json
if [[ "$(jq '.Objects | length' /tmp/dp-lab-del.json)" -gt 0 ]]; then
  aws s3api delete-objects --bucket "$DATA_BUCKET" --delete file:///tmp/dp-lab-del.json >/dev/null
fi
rm -f /tmp/dp-lab-del.json

log "Who accessed $SRC (S3 server access logs, can lag by a few hours):"
TMP=$(mktemp -d)
aws s3 cp "s3://$LOGS_BUCKET/data-bucket/" "$TMP" --recursive --only-show-errors || true
grep -h "$SRC" "$TMP"/* 2>/dev/null | awk '{print $3, $4, $6, $8, $10}' | redact || echo "  (no log lines yet)"
rm -rf "$TMP"

log "Done. Record this in week-4-compliance/macie-findings-report.md and risk R-01."
