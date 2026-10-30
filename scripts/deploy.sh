#!/usr/bin/env bash
# Deploys (or updates) the whole lab in order. Safe to re-run: unchanged stacks are skipped.
#
#   cp config.example.env config.env   # edit it first
#   ./scripts/deploy.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require aws jq zip python3
load_config

ACCOUNT=$(account_id)
log "Account $(echo "$ACCOUNT" | redact), region $AWS_REGION, suffix $SUFFIX"

CALLER_ARN=$(caller_principal_arn)
KEY_ADMIN=${KEY_ADMIN_ROLE_ARN:-$CALLER_ARN}
KEY_USER=${KEY_USER_ROLE_ARN:-$CALLER_ARN}

# 1. Foundation: CloudTrail, alerts topic, artifacts bucket, budget
deploy_stack dp-lab-foundation 00-foundation.yaml \
  "Suffix=$SUFFIX" "AlertEmail=$ALERT_EMAIL" "MonthlyBudgetUsd=${MONTHLY_BUDGET_USD:-20}"

# 2. KMS keys
deploy_stack dp-lab-kms 01-kms.yaml \
  "KeyAdminRoleArn=$KEY_ADMIN" "KeyUserRoleArn=$KEY_USER"

# 3. Account-level Block Public Access (no CloudFormation resource for this one)
log "Turning on account-level S3 Block Public Access"
aws s3control put-public-access-block --account-id "$ACCOUNT" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# 4. S3 data bucket, access point, analyzer
deploy_stack dp-lab-s3 02-s3.yaml \
  "Suffix=$SUFFIX" "CreateAccessAnalyzer=${CREATE_ACCESS_ANALYZER:-true}"

# 5. DynamoDB (+ optional RDS)
deploy_stack dp-lab-datastores 03-datastores.yaml \
  "EnableRds=${ENABLE_RDS:-false}" "DbEngineVersion=${RDS_ENGINE_VERSION:-17.6}"

# 6. Package the Lambda and deploy the app stack
ARTIFACTS=$(stack_output dp-lab-foundation ArtifactsBucketName)
BUILD_DIR=$(mktemp -d)
cp "$REPO_ROOT/app/handler.py" "$BUILD_DIR/"
(cd "$BUILD_DIR" && zip -q handler.zip handler.py)
HASH=$(sha256sum "$REPO_ROOT/app/handler.py" | cut -c1-12)
LAMBDA_KEY="lambda/handler-$HASH.zip"
aws s3 cp "$BUILD_DIR/handler.zip" "s3://$ARTIFACTS/$LAMBDA_KEY" --only-show-errors
rm -rf "$BUILD_DIR"

deploy_stack dp-lab-app 04-app.yaml \
  "LambdaS3Key=$LAMBDA_KEY" "EnableWaf=${ENABLE_WAF:-false}"

# 7. Macie / GuardDuty
deploy_stack dp-lab-detection 05-detection.yaml \
  "EnableMacie=${ENABLE_MACIE:-false}" "EnableGuardDuty=${ENABLE_GUARDDUTY:-false}"

# 8. Save outputs for the other scripts
cat > "$OUTPUTS_FILE" <<EOF
DATA_BUCKET=$(stack_output dp-lab-s3 DataBucketName)
LOGS_BUCKET=$(stack_output dp-lab-s3 LogsBucketName)
ACCESS_POINT_ARN=$(stack_output dp-lab-s3 AccessPointArn)
ANALYTICS_ROLE_ARN=$(stack_output dp-lab-s3 AnalyticsRoleArn)
ARTIFACTS_BUCKET=$ARTIFACTS
TRAIL_BUCKET=$(stack_output dp-lab-foundation TrailBucketName)
TABLE_NAME=$(stack_output dp-lab-datastores TableName)
API_URL=$(stack_output dp-lab-app ApiUrl)
API_ID=$(stack_output dp-lab-app ApiId)
USER_POOL_ID=$(stack_output dp-lab-app UserPoolId)
USER_POOL_CLIENT_ID=$(stack_output dp-lab-app UserPoolClientId)
SECRET_ARN=$(stack_output dp-lab-app SecretArn)
WAF_ENABLED=${ENABLE_WAF:-false}
RDS_ENABLED=${ENABLE_RDS:-false}
MACIE_ENABLED=${ENABLE_MACIE:-false}
GUARDDUTY_ENABLED=${ENABLE_GUARDDUTY:-false}
EOF
chmod 600 "$OUTPUTS_FILE"

# 9. Things CloudFormation can't do: EBS default encryption, SecureString, data, test user
"$REPO_ROOT/scripts/post-deploy.sh"

log "Done. API: $(stack_output dp-lab-app ApiUrl)"
log "Confirm the SNS subscription email if you haven't, then run ./tests/run-tests.sh"
