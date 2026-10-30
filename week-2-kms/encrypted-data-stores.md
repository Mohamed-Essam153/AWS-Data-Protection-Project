# Encrypted data stores

Deliverable 9. Owner: Ammar

| Store | Resource | Key | Where it's set | Test |
|---|---|---|---|---|
| S3 | `dp-lab-data-<suffix>` | `dp-lab-s3` + Bucket Key | [02-s3.yaml](../infra/02-s3.yaml) `BucketEncryption` | T04, T07 |
| S3 Glacier IR | `archive/patients-2024.csv` | `dp-lab-s3` | [post-deploy.sh](../scripts/post-deploy.sh) | T16 |
| DynamoDB | `dp-lab-customers` | `dp-lab-db` | [03-datastores.yaml](../infra/03-datastores.yaml) `SSESpecification` | T14 |
| RDS PostgreSQL (optional) | `dp-lab-db` | `dp-lab-db`, master secret on `dp-lab-secrets` | [03-datastores.yaml](../infra/03-datastores.yaml) | T17 |
| EBS | account default in the region | `dp-lab-ebs` | [post-deploy.sh](../scripts/post-deploy.sh) | T15 |
| Secrets Manager | `dp-lab/thirdparty/api-key` | `dp-lab-secrets` | [04-app.yaml](../infra/04-app.yaml) | T18 |
| Parameter Store | `/dp-lab/app/partner-endpoint` (SecureString) | `dp-lab-secrets` | [post-deploy.sh](../scripts/post-deploy.sh) | T19 |
| CloudTrail logs | `dp-lab-cloudtrail-<suffix>` | SSE-S3 | [00-foundation.yaml](../infra/00-foundation.yaml) | - |

## Notes per store

**S3.** Default encryption only applies to new objects. Our objects are uploaded after the bucket exists, so all of them are SSE-KMS from the start. On a bucket that already had data you'd re-encrypt in place: `aws s3 cp s3://bucket/ s3://bucket/ --recursive --sse aws:kms --sse-kms-key-id alias/dp-lab-s3`.

**DynamoDB.** Encryption at rest is always on. The choice is only which key; we picked our own so we can see and control its use. Point-in-time recovery is on too.

**RDS.** Off by default because it costs per hour. With `ENABLE_RDS=true` you get a small PostgreSQL 17 instance: storage encrypted with `dp-lab-db`, not publicly accessible, master password generated and kept by Secrets Manager (encrypted with `dp-lab-secrets`, rotated by RDS), and a parameter group with `rds.force_ssl = 1`. Encryption can only be chosen when an instance is created. To encrypt an existing one: snapshot, copy the snapshot with encryption on, restore from the copy. Snapshots and replicas inherit the key.

**EBS.** Encryption by default is a per-region account setting with no CloudFormation resource, so the script sets it. Every new volume in the region is encrypted with `dp-lab-ebs` even if whoever creates it forgets. Teardown turns it back off.

**Glacier.** We use the S3 Glacier storage classes, not the old Glacier vaults. Objects keep their SSE-KMS encryption when they move between classes. Legacy vaults always use AWS-managed AES-256 with no choice of key, which is one more reason to stay inside S3.

**CloudTrail logs.** SSE-S3 is enough for the lab. In production we'd put them on their own KMS key in a separate logging account.
