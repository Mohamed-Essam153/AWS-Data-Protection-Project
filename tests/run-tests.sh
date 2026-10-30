#!/usr/bin/env bash
# Checks every control against the live deployment and writes a redacted report to
# evidence/test-report-<timestamp>.md. Commit that file - it is the main evidence.
#
#   ./tests/run-tests.sh            # all tests
#   ./tests/run-tests.sh T17 T18    # only some
#
# With WAF on, wait ~5 minutes between full runs: the rate rule allows 100 requests
# per IP per 5 minutes and one run sends about 65.
set -uo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
require aws jq curl openssl
load_config
load_outputs

ACCOUNT=$(account_id)
DEMO_KEY_ID=$(aws kms describe-key --key-id alias/dp-lab-demo --query KeyMetadata.KeyId --output text)
STAMP=$(date +%Y%m%d-%H%M)
REPORT="$REPO_ROOT/evidence/test-report-$STAMP.md"
DETAILS=$(mktemp)
SUMMARY=$(mktemp)
WORK=$(mktemp -d)
PASS=0; FAIL=0; SKIP=0
ONLY=("$@")

trap 'aws kms enable-key --key-id "$DEMO_KEY_ID" >/dev/null 2>&1; rm -rf "$WORK" "$DETAILS" "$SUMMARY"' EXIT

wanted() { (( ${#ONLY[@]} == 0 )) && return 0; for t in "${ONLY[@]}"; do [[ $t == "$1" ]] && return 0; done; return 1; }

# record ID "title" PASS|FAIL|SKIP "evidence text"
record() {
  local id=$1 title=$2 status=$3 out=$4 icon
  case $status in PASS) ((PASS++)); icon="PASS";; FAIL) ((FAIL++)); icon="**FAIL**";; *) ((SKIP++)); icon="SKIP";; esac
  printf '%-4s %-5s %s\n' "$id" "$status" "$title"
  echo "| $id | $title | $icon |" >> "$SUMMARY"
  { echo "### $id - $title"; echo; echo "Result: $icon"; echo; echo '```'; echo "$out" | head -40; echo '```'; echo; } >> "$DETAILS"
}

api_code() { curl -s -o /dev/null -w '%{http_code}' -m 15 "$@"; }

# ------------------------------------------------------------------ Week 0
if wanted T01; then
  out=$(aws cloudtrail get-trail-status --name dp-lab-trail --query '{IsLogging:IsLogging,LatestDelivery:LatestDeliveryTime}' 2>&1)
  val=$(aws cloudtrail describe-trails --trail-name-list dp-lab-trail --query 'trailList[0].[LogFileValidationEnabled,IsMultiRegionTrail]' --output text 2>&1)
  out="$out"$'\n'"LogFileValidationEnabled / IsMultiRegionTrail: $val"
  [[ $(echo "$out" | jq -r .IsLogging 2>/dev/null) == true && $val == $'True\tTrue' ]] \
    && record T01 "CloudTrail logging with log file validation" PASS "$out" \
    || record T01 "CloudTrail logging with log file validation" FAIL "$out"
fi

if wanted T02; then
  out=$(aws budgets describe-budget --account-id "$ACCOUNT" --budget-name dp-lab-monthly \
        --query 'Budget.{Name:BudgetName,Limit:BudgetLimit,Unit:TimeUnit}' 2>&1)
  [[ $out == *dp-lab-monthly* ]] && record T02 "Monthly cost budget exists" PASS "$out" \
                                 || record T02 "Monthly cost budget exists" FAIL "$out"
fi

# ------------------------------------------------------------------ Week 1
if wanted T03; then
  out=$(aws s3control get-public-access-block --account-id "$ACCOUNT" 2>&1)
  [[ $(echo "$out" | jq '[.PublicAccessBlockConfiguration[]] | all' 2>/dev/null) == true ]] \
    && record T03 "Account-level Block Public Access is fully on" PASS "$out" \
    || record T03 "Account-level Block Public Access is fully on" FAIL "$out"
fi

if wanted T04; then
  v=$(aws s3api get-bucket-versioning --bucket "$DATA_BUCKET" --query Status --output text 2>&1)
  e=$(aws s3api get-bucket-encryption --bucket "$DATA_BUCKET" --query 'ServerSideEncryptionConfiguration.Rules[0].[ApplyServerSideEncryptionByDefault.SSEAlgorithm,BucketKeyEnabled]' --output text 2>&1)
  o=$(aws s3api get-bucket-ownership-controls --bucket "$DATA_BUCKET" --query 'OwnershipControls.Rules[0].ObjectOwnership' --output text 2>&1)
  b=$(aws s3api get-public-access-block --bucket "$DATA_BUCKET" --query 'PublicAccessBlockConfiguration' --output json 2>&1 | jq -c .)
  l=$(aws s3api get-bucket-logging --bucket "$DATA_BUCKET" --query 'LoggingEnabled.TargetBucket' --output text 2>&1)
  out="versioning: $v"$'\n'"encryption: $e"$'\n'"ownership: $o"$'\n'"block public access: $b"$'\n'"access logs to: $l"
  [[ $v == Enabled && $e == $'aws:kms\tTrue' && $o == BucketOwnerEnforced && $b != *false* && $l == "$LOGS_BUCKET" ]] \
    && record T04 "Data bucket baseline (versioning, SSE-KMS + Bucket Key, ACLs off, BPA, logging)" PASS "$out" \
    || record T04 "Data bucket baseline (versioning, SSE-KMS + Bucket Key, ACLs off, BPA, logging)" FAIL "$out"
fi

if wanted T05; then
  echo "t05 $(date)" > "$WORK/t05.txt"
  out=$(aws s3 cp "$WORK/t05.txt" "s3://$DATA_BUCKET/public/t05.txt" --sse AES256 2>&1)
  [[ $out == *AccessDenied* ]] \
    && record T05 "Upload asking for SSE-S3 (AES256) is denied by the bucket policy" PASS "\$ aws s3 cp t05.txt s3://<bucket>/public/ --sse AES256"$'\n'"$out" \
    || record T05 "Upload asking for SSE-S3 (AES256) is denied by the bucket policy" FAIL "$out"
fi

if wanted T06; then
  out=$(aws s3api list-objects-v2 --bucket "$DATA_BUCKET" --max-keys 1 \
        --endpoint-url "http://s3.$AWS_REGION.amazonaws.com" 2>&1)
  [[ $out == *AccessDenied* ]] \
    && record T06 "Plain HTTP request to the bucket is denied" PASS "\$ aws s3api list-objects-v2 --endpoint-url http://s3.$AWS_REGION.amazonaws.com ..."$'\n'"$out" \
    || record T06 "Plain HTTP request to the bucket is denied" FAIL "$out"
fi

if wanted T07; then
  echo "t07 $(date)" > "$WORK/t07.txt"
  aws s3 cp "$WORK/t07.txt" "s3://$DATA_BUCKET/public/t07.txt" --only-show-errors
  out=$(aws s3api head-object --bucket "$DATA_BUCKET" --key public/t07.txt \
        --query '{ServerSideEncryption:ServerSideEncryption,BucketKeyEnabled:BucketKeyEnabled,SSEKMSKeyId:SSEKMSKeyId}' 2>&1)
  aws s3 rm "s3://$DATA_BUCKET/public/t07.txt" --only-show-errors
  [[ $(echo "$out" | jq -r .ServerSideEncryption 2>/dev/null) == aws:kms ]] \
    && record T07 "Upload with no header is encrypted with SSE-KMS by default" PASS "$out" \
    || record T07 "Upload with no header is encrypted with SSE-KMS by default" FAIL "$out"
fi

if wanted T08; then
  creds=$(aws sts assume-role --role-arn "$ANALYTICS_ROLE_ARN" --role-session-name dp-lab-t08 --query Credentials --output json 2>&1)
  if [[ $(echo "$creds" | jq -r .AccessKeyId 2>/dev/null) == ASIA* ]]; then
    as_analytics() {
      AWS_ACCESS_KEY_ID=$(echo "$creds" | jq -r .AccessKeyId) \
      AWS_SECRET_ACCESS_KEY=$(echo "$creds" | jq -r .SecretAccessKey) \
      AWS_SESSION_TOKEN=$(echo "$creds" | jq -r .SessionToken) "$@"
    }
    ok=$(as_analytics aws s3api get-object --bucket "$ACCESS_POINT_ARN" --key internal/staff-directory.csv "$WORK/ok.csv" --query ContentLength 2>&1)
    no=$(as_analytics aws s3api get-object --bucket "$ACCESS_POINT_ARN" --key restricted/payments.csv "$WORK/no.csv" 2>&1)
    direct=$(as_analytics aws s3api get-object --bucket "$DATA_BUCKET" --key internal/staff-directory.csv "$WORK/d.csv" 2>&1)
    out="via access point, internal/staff-directory.csv -> bytes: $ok"$'\n'"via access point, restricted/payments.csv -> $no"$'\n'"direct to bucket, internal/staff-directory.csv -> $direct"
    [[ $ok =~ ^[0-9]+$ && $no == *AccessDenied* && $direct == *AccessDenied* ]] \
      && record T08 "Analytics role: internal/ allowed via access point, restricted/ and direct access denied" PASS "$out" \
      || record T08 "Analytics role: internal/ allowed via access point, restricted/ and direct access denied" FAIL "$out"
  else
    record T08 "Analytics role: internal/ allowed via access point, restricted/ and direct access denied" FAIL "$creds"
  fi
fi

if wanted T09; then
  arn=$(aws accessanalyzer list-analyzers --type ACCOUNT --query 'analyzers[0].arn' --output text 2>&1)
  out=$(aws accessanalyzer list-findings-v2 --analyzer-arn "$arn" \
        --filter '{"status":{"eq":["ACTIVE"]}}' --query 'findings[].{resource:resource,type:resourceType}' --output json 2>&1)
  n=$(echo "$out" | jq length 2>/dev/null || echo err)
  [[ $n == 0 ]] && record T09 "IAM Access Analyzer: no active external-access findings" PASS "analyzer: $arn"$'\n'"active findings: 0" \
                || record T09 "IAM Access Analyzer: no active external-access findings" FAIL "analyzer: $arn"$'\n'"$out"
fi

if wanted T10; then
  out=$(aws s3api get-bucket-lifecycle-configuration --bucket "$DATA_BUCKET" \
        --query 'Rules[].{id:ID,prefix:Prefix||Filter.Prefix,expireDays:Expiration.Days,noncurrentDays:NoncurrentVersionExpiration.NoncurrentDays}' --output json 2>&1)
  [[ $(echo "$out" | jq length 2>/dev/null) == 3 && $out == *restricted-short-retention* ]] \
    && record T10 "Lifecycle: 3 rules incl. 180-day retention for restricted/" PASS "$out" \
    || record T10 "Lifecycle: 3 rules incl. 180-day retention for restricted/" FAIL "$out"
fi

if wanted T11; then
  out=$(aws s3api get-object-tagging --bucket "$DATA_BUCKET" --key restricted/payments.csv --output json 2>&1)
  [[ $out == *Restricted* ]] && record T11 "Objects carry their DataClassification tag" PASS "restricted/payments.csv: $out" \
                             || record T11 "Objects carry their DataClassification tag" FAIL "$out"
fi

# ------------------------------------------------------------------ Week 2
if wanted T12; then
  out=""; allok=true
  for a in s3 db ebs secrets demo; do
    r=$(aws kms get-key-rotation-status --key-id "$(aws kms describe-key --key-id alias/dp-lab-$a --query KeyMetadata.KeyId --output text)" \
        --query '[KeyRotationEnabled,RotationPeriodInDays]' --output text 2>&1)
    out+="alias/dp-lab-$a: $r"$'\n'
    [[ $r == $'True\t365' ]] || allok=false
  done
  $allok && record T12 "All 5 customer managed keys rotate every 365 days" PASS "$out" \
         || record T12 "All 5 customer managed keys rotate every 365 days" FAIL "$out"
fi

if wanted T13; then
  echo "Fake card 4111-1111-1111-1111 for the KMS lab" > "$WORK/plain.txt"
  aws kms encrypt --key-id alias/dp-lab-demo --plaintext "fileb://$WORK/plain.txt" \
    --query CiphertextBlob --output text | base64 --decode > "$WORK/cipher.bin"
  back=$(aws kms decrypt --ciphertext-blob "fileb://$WORK/cipher.bin" --query Plaintext --output text | base64 --decode)
  aws kms disable-key --key-id "$DEMO_KEY_ID"   # also fires the dp-lab-kms-critical-changes email
  sleep 3
  denied=$(aws kms decrypt --ciphertext-blob "fileb://$WORK/cipher.bin" 2>&1)
  aws kms enable-key --key-id "$DEMO_KEY_ID"
  out="ciphertext (first bytes): $(od -An -tx1 -N16 "$WORK/cipher.bin" | tr -d " \n")"$'\n'"decrypt while enabled: $back"$'\n'"decrypt while disabled: $denied"$'\n'"key re-enabled afterwards"
  [[ $back == "$(cat "$WORK/plain.txt")" && $denied == *DisabledException* ]] \
    && record T13 "KMS lab: encrypt/decrypt works, disabled key -> DisabledException" PASS "$out" \
    || record T13 "KMS lab: encrypt/decrypt works, disabled key -> DisabledException" FAIL "$out"
fi

if wanted T14; then
  out=$(aws dynamodb describe-table --table-name "$TABLE_NAME" --query 'Table.SSEDescription' --output json 2>&1)
  dbkey=$(aws kms describe-key --key-id alias/dp-lab-db --query KeyMetadata.Arn --output text)
  [[ $(echo "$out" | jq -r .SSEType 2>/dev/null) == KMS && $(echo "$out" | jq -r .KMSMasterKeyArn) == "$dbkey" ]] \
    && record T14 "DynamoDB table encrypted with the dp-lab-db customer managed key" PASS "$out" \
    || record T14 "DynamoDB table encrypted with the dp-lab-db customer managed key" FAIL "$out"
fi

if wanted T15; then
  on=$(aws ec2 get-ebs-encryption-by-default --query EbsEncryptionByDefault --output text 2>&1)
  kid=$(aws ec2 get-ebs-default-kms-key-id --query KmsKeyId --output text 2>&1)
  karn=$(aws kms describe-key --key-id "$kid" --query KeyMetadata.Arn --output text 2>&1)
  ebs=$(aws kms describe-key --key-id alias/dp-lab-ebs --query KeyMetadata.Arn --output text)
  out="EbsEncryptionByDefault: $on"$'\n'"default key: $kid"
  [[ $on == True && $karn == "$ebs" ]] && record T15 "EBS encryption by default with alias/dp-lab-ebs" PASS "$out" \
                                       || record T15 "EBS encryption by default with alias/dp-lab-ebs" FAIL "$out"
fi

if wanted T16; then
  out=$(aws s3api head-object --bucket "$DATA_BUCKET" --key archive/patients-2024.csv \
        --query '{StorageClass:StorageClass,ServerSideEncryption:ServerSideEncryption}' --output json 2>&1)
  [[ $out == *GLACIER_IR* && $out == *aws:kms* ]] \
    && record T16 "Archived object in Glacier Instant Retrieval is still SSE-KMS" PASS "$out" \
    || record T16 "Archived object in Glacier Instant Retrieval is still SSE-KMS" FAIL "$out"
fi

if wanted T17; then
  if [[ $RDS_ENABLED == true ]]; then
    db=$(aws rds describe-db-instances --db-instance-identifier dp-lab-db \
         --query 'DBInstances[0].{Encrypted:StorageEncrypted,Public:PubliclyAccessible,ParamGroup:DBParameterGroups[0].DBParameterGroupName}' --output json 2>&1)
    pg=$(echo "$db" | jq -r .ParamGroup)
    ssl=$(aws rds describe-db-parameters --db-parameter-group-name "$pg" \
          --query "Parameters[?ParameterName=='rds.force_ssl'].ParameterValue | [0]" --output text 2>&1)
    out="$db"$'\n'"rds.force_ssl = $ssl"
    [[ $(echo "$db" | jq -r .Encrypted) == true && $(echo "$db" | jq -r .Public) == false && $ssl == 1 ]] \
      && record T17 "RDS: encrypted, not public, TLS forced" PASS "$out" \
      || record T17 "RDS: encrypted, not public, TLS forced" FAIL "$out"
  else
    record T17 "RDS: encrypted, not public, TLS forced" SKIP "ENABLE_RDS=false"
  fi
fi

# ------------------------------------------------------------------ Week 3
if wanted T18; then
  aws secretsmanager put-secret-value --secret-id "$SECRET_ARN" \
    --secret-string "{\"provider\":\"fake-partner\",\"api_key\":\"$(aws secretsmanager get-random-password --exclude-punctuation --password-length 32 --query RandomPassword --output text)\"}" >/dev/null
  out=$(aws secretsmanager list-secret-version-ids --secret-id "$SECRET_ARN" \
        --query 'Versions[].{Version:VersionId,Stages:VersionStages}' --output json 2>&1)
  [[ $out == *AWSCURRENT* && $out == *AWSPREVIOUS* ]] \
    && record T18 "Secret rotated: new AWSCURRENT, old kept as AWSPREVIOUS (values never printed)" PASS "$out" \
    || record T18 "Secret rotated: new AWSCURRENT, old kept as AWSPREVIOUS (values never printed)" FAIL "$out"
fi

if wanted T19; then
  out=$(aws ssm describe-parameters --parameter-filters "Key=Name,Values=/dp-lab/app/partner-endpoint" \
        --query 'Parameters[0].{Name:Name,Type:Type,KeyId:KeyId}' --output json 2>&1)
  [[ $out == *SecureString* && $out == *dp-lab-secrets* ]] \
    && record T19 "Partner endpoint stored as SecureString with alias/dp-lab-secrets" PASS "$out" \
    || record T19 "Partner endpoint stored as SecureString with alias/dp-lab-secrets" FAIL "$out"
fi

HOST=$(echo "$API_URL" | cut -d/ -f3)

if wanted T20; then
  pol=$(aws apigateway get-rest-api --rest-api-id "$API_ID" --query '[securityPolicy,endpointAccessMode]' --output text 2>&1)
  neg=$(curl -sv -o /dev/null -m 15 "$API_URL" 2>&1 | grep -E "SSL connection using|issuer:|expire date:" | sed 's/^[* ]*//')
  old=$(curl -s -o /dev/null -w '%{http_code}' -m 15 --tlsv1.0 --tls-max 1.1 "$API_URL" 2>&1); oldrc=$?
  out="API security policy / access mode: $pol"$'\n'"$neg"$'\n'"forcing TLS 1.0-1.1 -> curl exit $oldrc, http $old"
  [[ $pol == SecurityPolicy_TLS13_1_2_2021_06* && $neg == *TLSv1.[23]* && $old == 000 ]] \
    && record T20 "API accepts only TLS 1.2+ (policy set, 1.2/1.3 negotiated, 1.0/1.1 refused)" PASS "$out" \
    || record T20 "API accepts only TLS 1.2+ (policy set, 1.2/1.3 negotiated, 1.0/1.1 refused)" FAIL "$out"
fi

if wanted T21; then
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 8 "http://$HOST/prod/customer" 2>&1)
  [[ $code != 200 ]] && record T21 "Plain HTTP to the API gets no response" PASS "\$ curl http://<api-host>/prod/customer -> http code $code (000 = no connection)" \
                     || record T21 "Plain HTTP to the API gets no response" FAIL "http code $code"
fi

TOKEN=$("$REPO_ROOT/scripts/get-token.sh" 2>/dev/null || true)

if wanted T22; then
  c=$(api_code "$API_URL")
  [[ $c == 401 ]] && record T22 "API without a token -> 401" PASS "\$ curl \$API_URL -> $c" \
                  || record T22 "API without a token -> 401" FAIL "\$ curl \$API_URL -> $c"
fi

if wanted T23; then
  body=$(curl -s -m 15 -H "Authorization: $TOKEN" "$API_URL" -w '\nhttp %{http_code}')
  [[ $body == *"http 200"* && $body == *'"customerId": "C-0001"'* && $body != *@* ]] \
    && record T23 "API with a Cognito token -> 200, response has no personal data" PASS "$body" \
    || record T23 "API with a Cognito token -> 200, response has no personal data" FAIL "$body"
fi

if wanted T24; then
  if [[ $WAF_ENABLED == true ]]; then
    c=$(curl -G -s -o /dev/null -w '%{http_code}' -m 15 -H "Authorization: $TOKEN" \
        --data-urlencode "q=<script>alert(1)</script>" "$API_URL")
    [[ $c == 403 ]] && record T24 "WAF blocks an XSS attempt -> 403" PASS "\$ curl -G --data-urlencode 'q=<script>alert(1)</script>' \$API_URL -> $c" \
                    || record T24 "WAF blocks an XSS attempt -> 403" FAIL "-> $c"
  else
    record T24 "WAF blocks an XSS attempt -> 403" SKIP "ENABLE_WAF=false"
  fi
fi

if wanted T25; then
  for _ in $(seq 1 60); do api_code -H "Authorization: $TOKEN" "$API_URL" >> "$WORK/burst.txt" & done; wait
  echo >> "$WORK/burst.txt"
  out=$(grep -oE '[0-9]{3}' "$WORK/burst.txt" | sort | uniq -c)
  [[ $out == *429* ]] && record T25 "60 requests at once -> some throttled with 429 (5 rps, burst 10)" PASS "count  status"$'\n'"$out" \
                      || record T25 "60 requests at once -> some throttled with 429 (5 rps, burst 10)" FAIL "$out"
fi

# ------------------------------------------------------------------ Week 4
if wanted T26; then
  if [[ $MACIE_ENABLED == true ]]; then
    out=$(aws macie2 get-macie-session --query '{status:status,frequency:findingPublishingFrequency}' --output json 2>&1)
    n=$(aws macie2 list-findings --query 'length(findingIds)' --output text 2>&1)
    out+=$'\n'"findings so far: $n"
    [[ $out == *ENABLED* ]] && record T26 "Macie enabled (findings listed by scripts/macie-findings.sh)" PASS "$out" \
                            || record T26 "Macie enabled (findings listed by scripts/macie-findings.sh)" FAIL "$out"
  else
    record T26 "Macie enabled (findings listed by scripts/macie-findings.sh)" SKIP "ENABLE_MACIE=false"
  fi
fi

if wanted T27; then
  if [[ $GUARDDUTY_ENABLED == true ]]; then
    det=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
    out=$(aws guardduty get-detector --detector-id "$det" \
          --query "{Status:Status,S3:Features[?Name=='S3_DATA_EVENTS'].Status|[0]}" --output json 2>&1)
    [[ $out == *ENABLED* && $(echo "$out" | jq -r .S3) == ENABLED ]] \
      && record T27 "GuardDuty on with S3 Protection" PASS "$out" \
      || record T27 "GuardDuty on with S3 Protection" FAIL "$out"
  else
    record T27 "GuardDuty on with S3 Protection" SKIP "ENABLE_GUARDDUTY=false"
  fi
fi

if wanted T28; then
  out=$(aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventSource,AttributeValue=kms.amazonaws.com \
        --max-results 10 --query 'Events[].[EventTime,EventName,Username]' --output text 2>&1)
  [[ -n $out && $out != *rror* ]] \
    && record T28 "KMS API calls show up in CloudTrail" PASS "$out" \
    || record T28 "KMS API calls show up in CloudTrail" FAIL "${out:-no events yet - CloudTrail can lag ~15 min, re-run T28 later}"
fi

# ------------------------------------------------------------------ report
{
  echo "# Test report $STAMP"
  echo
  echo "- Region: $AWS_REGION"
  echo "- Run by: $(aws sts get-caller-identity --query Arn --output text | sed -E 's#/[^/]+$#/<session>#')"
  echo "- Options: WAF=$WAF_ENABLED, RDS=$RDS_ENABLED, Macie=$MACIE_ENABLED, GuardDuty=$GUARDDUTY_ENABLED"
  echo "- Result: $PASS passed, $FAIL failed, $SKIP skipped"
  echo
  echo "| ID | Check | Result |"
  echo "|---|---|---|"
  cat "$SUMMARY"
  echo
  echo "## Details"
  echo
  cat "$DETAILS"
} | redact > "$REPORT"

echo
log "$PASS passed, $FAIL failed, $SKIP skipped"
log "Report: ${REPORT#"$REPO_ROOT"/}"
(( FAIL == 0 ))
