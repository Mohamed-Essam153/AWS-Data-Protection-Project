#!/usr/bin/env bash
# Removes everything the lab created. Run it after the demo, once evidence is committed.
# KMS keys go last (scheduled for deletion, 7-day waiting period) because everything
# else is encrypted with them.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
require aws jq
load_config

read -r -p "This deletes the whole dp-lab deployment in $AWS_REGION. Type the suffix ($SUFFIX) to continue: " answer
[[ "$answer" == "$SUFFIX" ]] || die "Cancelled"

empty_bucket() {
  local b=$1
  aws s3api head-bucket --bucket "$b" >/dev/null 2>&1 || return 0
  log "Emptying s3://$b (all versions)"
  while :; do
    local batch
    batch=$(aws s3api list-object-versions --bucket "$b" --max-items 1000 --output json \
            | jq -c '{Objects: ([.Versions[]?, .DeleteMarkers[]?] | map({Key, VersionId})), Quiet: true}')
    [[ $(echo "$batch" | jq '.Objects | length') -gt 0 ]] || break
    aws s3api delete-objects --bucket "$b" --delete "$batch" >/dev/null
  done
}

delete_stack() {
  aws cloudformation describe-stacks --stack-name "$1" >/dev/null 2>&1 || return 0
  log "Deleting stack $1"
  aws cloudformation delete-stack --stack-name "$1"
  aws cloudformation wait stack-delete-complete --stack-name "$1" \
    || die "$1 did not delete cleanly - check its Events tab, fix, and re-run"
}

delete_stack dp-lab-detection
delete_stack dp-lab-app
aws ssm delete-parameter --name /dp-lab/app/partner-endpoint 2>/dev/null || true
delete_stack dp-lab-datastores

empty_bucket "dp-lab-data-$SUFFIX"
empty_bucket "dp-lab-logs-$SUFFIX"
delete_stack dp-lab-s3

log "Resetting EBS default encryption to the AWS managed key (and turning it off)"
aws ec2 reset-ebs-default-kms-key-id >/dev/null
aws ec2 disable-ebs-encryption-by-default >/dev/null

delete_stack dp-lab-kms   # schedules deletion of the 5 keys

empty_bucket "dp-lab-artifacts-$SUFFIX"
empty_bucket "dp-lab-cloudtrail-$SUFFIX"
delete_stack dp-lab-foundation

rm -rf "$STATE_DIR"

log "Left behind on purpose:"
echo "  - account-level S3 Block Public Access (keep it on)"
echo "  - the API Gateway account CloudWatch role setting"
log "Check nothing is left: aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=DataProtection"
