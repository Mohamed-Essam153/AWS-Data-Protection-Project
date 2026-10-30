#!/usr/bin/env bash
# Steps CloudFormation has no resource for. Called by deploy.sh; safe to re-run on its own.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require aws jq python3
load_config
load_outputs

# --- EBS default encryption (per region) --------------------------------------
log "EBS: encrypt new volumes by default with alias/dp-lab-ebs"
aws ec2 enable-ebs-encryption-by-default >/dev/null
aws ec2 modify-ebs-default-kms-key-id --kms-key-id alias/dp-lab-ebs >/dev/null

# --- SecureString parameter (CloudFormation only creates String/StringList) ---
log "Parameter Store: /dp-lab/app/partner-endpoint as SecureString"
aws ssm put-parameter --name /dp-lab/app/partner-endpoint --type SecureString \
  --key-id alias/dp-lab-secrets --value "https://partner.example.com/v1" --overwrite >/dev/null

# --- Fake data ----------------------------------------------------------------
log "Generating fake data"
python3 -c "import faker" 2>/dev/null || pip3 install --user --quiet faker
(cd "$REPO_ROOT" && python3 tools/generate_fake_data.py)

upload() {  # file  prefix  classification
  local key
  key="$2/$(basename "$1")"
  aws s3 cp "$1" "s3://$DATA_BUCKET/$key" --only-show-errors
  aws s3api put-object-tagging --bucket "$DATA_BUCKET" --key "$key" \
    --tagging "TagSet=[{Key=DataClassification,Value=$3}]"
}

log "Uploading fake data to s3://$DATA_BUCKET by classification"
D="$REPO_ROOT/data"
upload "$D/products.csv"        public       Public
upload "$D/staff-directory.csv" internal     Internal
upload "$D/notes-export.csv"    internal     Internal      # the planted mistake for Macie
upload "$D/customers.csv"       confidential Confidential
upload "$D/payments.csv"        restricted   Restricted
upload "$D/patients.csv"        restricted   Restricted
aws s3 cp "$D/patients.csv" "s3://$DATA_BUCKET/archive/patients-2024.csv" \
  --storage-class GLACIER_IR --only-show-errors

# --- DynamoDB seed rows (fake) --------------------------------------------------
log "Seeding $TABLE_NAME"
for i in 1 2 3; do
  tier=$([[ $i == 1 ]] && echo gold || echo silver)
  aws dynamodb put-item --table-name "$TABLE_NAME" --item \
    "{\"customerId\":{\"S\":\"C-000$i\"},\"tier\":{\"S\":\"$tier\"},\"name\":{\"S\":\"Fake Customer $i\"},\"email\":{\"S\":\"customer$i@example.com\"}}"
done

# --- Cognito test user ----------------------------------------------------------
if [[ ! -f "$TEST_USER_FILE" ]] || \
   ! aws cognito-idp admin-get-user --user-pool-id "$USER_POOL_ID" \
       --username "$(jq -r .username "$TEST_USER_FILE")" >/dev/null 2>&1; then
  log "Creating Cognito test user (password saved to $TEST_USER_FILE, never in the repo)"
  USERNAME="dp-lab-tester@example.com"
  PASSWORD=$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("Dp!" + "".join(secrets.choice(a) for _ in range(20)) + "9a")')
  aws cognito-idp admin-create-user --user-pool-id "$USER_POOL_ID" --username "$USERNAME" \
    --message-action SUPPRESS >/dev/null 2>&1 || true
  aws cognito-idp admin-set-user-password --user-pool-id "$USER_POOL_ID" --username "$USERNAME" \
    --password "$PASSWORD" --permanent
  umask 077
  jq -n --arg u "$USERNAME" --arg p "$PASSWORD" '{username:$u,password:$p}' > "$TEST_USER_FILE"
fi

log "Post-deploy steps done"
