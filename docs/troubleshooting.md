# Troubleshooting

**`deploy.sh` says a bucket already exists.** Bucket names are global. Change `SUFFIX`.

**`dp-lab-kms` fails with "MalformedPolicyDocument".** The role ARN in `KEY_ADMIN_ROLE_ARN` / `KEY_USER_ROLE_ARN` doesn't exist or was typed wrong. Identity Center roles have a path, e.g. `arn:aws:iam::<account>:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_...`. Leave both empty and the script works it out for you.

**`dp-lab-s3` fails creating the analyzer.** There is already an account analyzer in this region. Set `CREATE_ACCESS_ANALYZER=false`.

**`dp-lab-detection` fails on the detector.** GuardDuty is already on in this account. Set `ENABLE_GUARDDUTY=false`; T27 can't check it then, but the console still shows it.

**`dp-lab-datastores` fails with an engine version error.** RDS retired that minor version. Run `aws rds describe-db-engine-versions --engine postgres --engine-version 17 --default-only --query 'DBEngineVersions[0].EngineVersion'` and put it in `RDS_ENGINE_VERSION` in `config.env`.

**AccessDenied when uploading to the data bucket.** You passed `--sse AES256` (denied on purpose) or your role can't use the S3 key. Upload without `--sse`.

**Macie reports objects as "unclassifiable".** Its service-linked role can't decrypt. The S3 key policy has a statement for it (`AllowMacieToDecrypt`, see [Macie docs](https://docs.aws.amazon.com/macie/latest/user/discovery-supported-encryption-types.html)); make sure `dp-lab-kms` is up to date.

**API returns 401 even with a token.** The token expired (60 minutes) or you used the access token instead of the ID token. `export TOKEN=$(./scripts/get-token.sh)` again.

**API returns 403 for everything.** WAF's rate rule blocked your IP for a few minutes. Wait 5 minutes.

**API returns 502.** Look at the function logs: `aws logs tail /aws/lambda/dp-lab-api-fn --since 10m`. Usually the SecureString parameter is missing; run `./scripts/post-deploy.sh`.

**No alert emails.** You didn't confirm the SNS subscription. Check spam for the confirmation from AWS Notifications.

**You can't find a teammate's resource.** Wrong region in the console.
