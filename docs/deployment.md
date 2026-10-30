# Deployment

## Before you start

- An AWS account where you sign in through IAM Identity Center with MFA. If the account is brand new, do [week 0](../week-0-setup/account-setup.md) first. Don't deploy as the root user, the script refuses to.
- One region for everything. We use `us-east-1`.
- AWS CloudShell. It already has the AWS CLI, `jq`, `zip`, `curl`, `openssl` and Python 3, and it is signed in as you, so there are no access keys to manage.

## 1. Get the code and configure

```bash
git clone https://github.com/Mohamed-Essam153/AWS-Data-Protection-Project.git
cd AWS-Data-Protection-Project
cp config.example.env config.env
nano config.env
```

The values that matter:

| Setting | What to put |
|---|---|
| `SUFFIX` | 4-8 lowercase letters/digits. Bucket names are global, so pick something unlikely to be taken. Everyone on the team uses the same one. |
| `ALERT_EMAIL` | Where security alerts and budget alerts go |
| `OWNER` | Your name, ends up in the `Owner` tag |
| `ENABLE_*` | Leave `false` for the first deploy |

`config.env` is in `.gitignore`.

## 2. Deploy

```bash
./scripts/deploy.sh
```

What it does, in order:

1. `dp-lab-foundation`: CloudTrail, SNS topic, artifacts bucket, budget
2. `dp-lab-kms`: the five keys. The role you are signed in with becomes key admin and key user unless you set `KEY_ADMIN_ROLE_ARN` / `KEY_USER_ROLE_ARN`
3. Account-level S3 Block Public Access
4. `dp-lab-s3`: data and logs buckets, bucket policy, access point, Access Analyzer
5. `dp-lab-datastores`: DynamoDB (and RDS if enabled)
6. Zips [app/handler.py](../app/handler.py), uploads it, deploys `dp-lab-app`
7. `dp-lab-detection`: Macie and GuardDuty if enabled
8. [post-deploy.sh](../scripts/post-deploy.sh): EBS default encryption, the SecureString parameter, fake data upload, DynamoDB rows, Cognito test user

Outputs (bucket names, API URL, pool IDs) are saved to `~/.dp-lab/outputs.env` in your CloudShell home. The Cognito test user's password is generated randomly and kept in `~/.dp-lab/test-user.json`, never in the repo.

AWS sends a confirmation email for the SNS subscription. Click it, otherwise you won't get any alerts.

## 3. Test

```bash
./tests/run-tests.sh
```

See [testing.md](testing.md). The report lands in `evidence/`.

## Turning the paid parts on and off

Edit `config.env` and run `./scripts/deploy.sh` again. Only the changed stacks are updated.

| Flag | Needed for |
|---|---|
| `ENABLE_RDS=true` | Week 2 RDS evidence and the `rds.force_ssl` check (test T17). Takes ~10 minutes to create. |
| `ENABLE_WAF=true` | Week 3 WAF test (T24) and the demo |
| `ENABLE_MACIE=true` | Week 4 - then run `./scripts/run-macie-job.sh` |
| `ENABLE_GUARDDUTY=true` | Week 4 - then run `./scripts/guardduty-samples.sh` |

If the account already has a GuardDuty detector or an Access Analyzer in the region, leave `ENABLE_GUARDDUTY=false` / set `CREATE_ACCESS_ANALYZER=false`, the existing ones work just as well for the tests.

## Updating the Lambda

Change [app/handler.py](../app/handler.py), run the unit tests, then `./scripts/deploy.sh`. The zip name includes a hash of the file, so CloudFormation picks up the new code.

```bash
pip install -r tests/requirements.txt
python -m pytest tests/unit -q
```

## Team workflow

Each member works in a branch (`week-2/kms-keys`, `week-3/api-waf`, ...) and opens a pull request. The lead reviews, checks there is nothing sensitive in the diff, and merges. Details in [team.md](team.md).
