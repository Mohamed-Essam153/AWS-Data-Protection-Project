# S3 secure baseline

Deliverable 2. Owner: Ahmed Shaaban. Template: [02-s3.yaml](../infra/02-s3.yaml)

Buckets: `dp-lab-data-<suffix>` for data, `dp-lab-logs-<suffix>` for its server access logs.

| # | Control | How it's set | Why | Test |
|---|---|---|---|---|
| 1 | Account Block Public Access | all four settings on (`deploy.sh`) | No bucket in the account can go public, whatever its own settings | T03 |
| 2 | Bucket Block Public Access | all four on | Second layer in case someone turns the account setting off | T04 |
| 3 | Object Ownership | `BucketOwnerEnforced` (ACLs disabled) | Only policies grant access, no forgotten per-object ACLs | T04 |
| 4 | Versioning | Enabled | Undo deletes and overwrites, survive ransomware | T04 |
| 5 | Default encryption | SSE-KMS with `alias/dp-lab-s3`, Bucket Key on | Our key, auditable, far fewer KMS calls | T04, T07 |
| 6 | Server access logs | to `dp-lab-logs-<suffix>/data-bucket/` | Who touched which object and when | T04 |
| 7 | Bucket policy | HTTPS only, TLS 1.2+, no non-KMS uploads, access via our access points | Encryption in transit and at rest enforced, not just configured | T05, T06 |
| 8 | Access point | `dp-lab-analytics-ap`, `internal/` read only | Share part of a bucket without opening all of it | T08 |
| 9 | Lifecycle | archive and expire by classification | Don't keep data longer than needed | T10 |
| 10 | Access Analyzer | account analyzer | Flags anything shared outside the account | T09 |
| 11 | Tags | Owner, Environment, Project, DataClassification=Restricted | Ownership, cost, teardown | console |

The logs bucket uses SSE-S3 rather than our KMS key because S3 server access logging can't deliver to a bucket whose default encryption is SSE-KMS.

## Checking it by hand

```bash
source ~/.dp-lab/outputs.env
aws s3api get-bucket-versioning          --bucket $DATA_BUCKET
aws s3api get-public-access-block        --bucket $DATA_BUCKET
aws s3api get-bucket-encryption          --bucket $DATA_BUCKET
aws s3api get-bucket-ownership-controls  --bucket $DATA_BUCKET
aws s3api get-bucket-logging             --bucket $DATA_BUCKET
```

The same calls run as T04 and their output is in the [test report](../evidence/).
