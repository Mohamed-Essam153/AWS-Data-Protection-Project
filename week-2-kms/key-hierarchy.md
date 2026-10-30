# KMS key hierarchy

Deliverable 7. Owner: Ammar. Template: [01-kms.yaml](../infra/01-kms.yaml)

## Envelope encryption

```
KMS key            stays inside KMS, every use is logged in CloudTrail
  └─ encrypts ─>  data key      stored (encrypted) next to the data
                    └─ encrypts ─>  the data   AES-256, done by the service
```

KMS will only encrypt up to 4 KB directly, so services don't send your data to KMS. They ask KMS for a data key (`GenerateDataKey`), use the plaintext copy to encrypt locally, throw it away, and keep the encrypted copy beside the data. To read, they send the encrypted copy back to KMS for `Decrypt`. The root of trust never leaves KMS.

On top of that, S3 Bucket Keys let S3 derive a short-lived bucket-level key and make data keys from it, instead of calling KMS for every object. That cuts KMS requests (and cost) a lot. The trade-off is that CloudTrail shows fewer, bucket-level KMS events. ([AWS docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html))

## Our keys

| Alias | Protects | Highest classification | Used by |
|---|---|---|---|
| `alias/dp-lab-s3` | data bucket, including Glacier IR objects | Restricted | team role, Lambda (via S3), analytics role (via S3), Macie |
| `alias/dp-lab-db` | DynamoDB table, RDS storage | Confidential | the services, through grants |
| `alias/dp-lab-ebs` | default for new EBS volumes | Internal | EC2, through grants |
| `alias/dp-lab-secrets` | Secrets Manager secrets, SecureString parameters | Restricted | Lambda (via Secrets Manager / SSM) |
| `alias/dp-lab-demo` | nothing real, KMS lab only | - | us, and it's the one we disable on purpose |

**Why five keys and not one?** Blast radius. If one key is disabled by mistake, or its policy is too loose, only that domain is affected. Each policy can also name exactly the principals that need it.

## Key types

| Type | Example | What we control | Cost |
|---|---|---|---|
| AWS owned | used silently by some services | nothing, you can't even see it | free |
| AWS managed | `aws/s3`, `aws/rds` | can see it and its usage; can't change policy or rotation | free to store |
| Customer managed (ours) | `alias/dp-lab-*` | policy, rotation, grants, disable, delete | about $1 per key per month |

We went with customer managed keys because the whole point of the week is to control who can use a key and to be able to switch it off.
