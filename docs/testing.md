# Testing

There are two kinds of tests.

**Live tests** ([tests/run-tests.sh](../tests/run-tests.sh)) run against the deployed lab and check that each control actually does what we say it does. Each one prints PASS / FAIL / SKIP, and the whole run is written to `evidence/test-report-<time>.md` with the account ID redacted. That report is our main evidence; commit it.

```bash
./tests/run-tests.sh            # everything
./tests/run-tests.sh T22 T23    # just a few
```

**Unit tests** ([tests/unit/test_handler.py](../tests/unit/test_handler.py)) check the Lambda code with moto, no AWS account needed.

```bash
pip install -r tests/requirements.txt
python -m pytest tests/unit -q
```

## The live tests

| ID | Week | What it proves | How |
|---|---|---|---|
| T01 | 0 | CloudTrail is logging, with log file validation and multi-region | `get-trail-status`, `describe-trails` |
| T02 | 0 | A monthly budget exists | `budgets describe-budget` |
| T03 | 1 | Account-level Block Public Access is fully on | `s3control get-public-access-block` |
| T04 | 1 | Data bucket baseline: versioning, SSE-KMS with Bucket Key, ACLs disabled, BPA, access logging | five `s3api get-*` calls |
| T05 | 1 | An upload asking for SSE-S3 is rejected | `aws s3 cp --sse AES256` gets AccessDenied |
| T06 | 1 | Plain HTTP to the bucket is rejected | request through an `http://` endpoint gets AccessDenied |
| T07 | 1 | An upload with no encryption header still ends up SSE-KMS | `head-object` shows `aws:kms` |
| T08 | 1 | Least privilege through the access point | analytics role can read `internal/`, gets AccessDenied on `restricted/` and on the bucket directly |
| T09 | 1 | Access Analyzer has no active findings | `list-findings-v2` |
| T10 | 1 | The three lifecycle rules are in place | `get-bucket-lifecycle-configuration` |
| T11 | 1 | Objects carry their classification tag | `get-object-tagging` |
| T12 | 2 | All five keys rotate every 365 days | `get-key-rotation-status` |
| T13 | 2 | KMS lab: encrypt/decrypt works, and a disabled key can't decrypt | `DisabledException`, key re-enabled after |
| T14 | 2 | DynamoDB uses our `dp-lab-db` key | `describe-table` |
| T15 | 2 | New EBS volumes are encrypted by default with `dp-lab-ebs` | `get-ebs-encryption-by-default` |
| T16 | 2 | Archived object in Glacier IR is still SSE-KMS | `head-object` |
| T17 | 2 | RDS is encrypted, private and forces TLS | skipped unless `ENABLE_RDS=true` |
| T18 | 3 | Secret rotation keeps the old version as AWSPREVIOUS | `put-secret-value` + `list-secret-version-ids` (values never printed) |
| T19 | 3 | Partner endpoint is a SecureString on `dp-lab-secrets` | `describe-parameters` |
| T20 | 3 | API only speaks TLS 1.2+ | security policy on the API, negotiated version, forced TLS 1.0/1.1 fails |
| T21 | 3 | Plain HTTP to the API gets nothing | `curl http://...` |
| T22 | 3 | No token, no access | 401 |
| T23 | 3 | With a Cognito token you get data, but no personal data | 200, body has no emails |
| T24 | 3 | WAF blocks an XSS attempt | 403, skipped unless `ENABLE_WAF=true` |
| T25 | 3 | Throttling kicks in | 60 parallel requests, some 429 |
| T26 | 4 | Macie is on | skipped unless `ENABLE_MACIE=true` |
| T27 | 4 | GuardDuty is on with S3 Protection | skipped unless `ENABLE_GUARDDUTY=true` |
| T28 | 4 | KMS calls are visible in CloudTrail | `lookup-events` |

## Things that can trip you up

- **T13 sends an alert email.** Disabling the demo key fires the `dp-lab-kms-critical-changes` rule. That's on purpose: it proves the alarm works. Screenshot the email.
- **T28 right after the first deploy** may fail because CloudTrail event history lags by up to ~15 minutes. Run `./tests/run-tests.sh T28` again later.
- **With WAF on**, the rate rule allows 100 requests per IP per 5 minutes and a full run sends about 65. Wait 5 minutes between full runs or T22-T25 will all get 403.
- **T20 and old TLS:** the main check is the API's security policy (`SecurityPolicy_TLS13_1_2_2021_06`, see [AWS docs](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-security-policies-list.html)). CloudShell's own OpenSSL may also refuse TLS 1.0/1.1, so the curl part on its own isn't proof.
- **T09** fails if your account has something else shared publicly or cross-account. Read the finding; if it isn't ours, archive it with a reason and note it in the access review.
