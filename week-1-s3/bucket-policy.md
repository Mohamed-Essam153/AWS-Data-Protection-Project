# Bucket policy

Deliverable 3. Owner: Ahmed Shaaban. The applied policy is `DataBucketPolicy` in [02-s3.yaml](../infra/02-s3.yaml).

## What we applied

| Sid | Effect | What it does | Test |
|---|---|---|---|
| `DenyInsecureTransport` | Deny | Any request where `aws:SecureTransport` is false, i.e. plain HTTP | T06 |
| `DenyOldTLS` | Deny | Any request over TLS older than 1.2 (`s3:TlsVersion`) | - |
| `DenyWrongEncryptionHeader` | Deny | A `PutObject` that explicitly asks for something other than `aws:kms` | T05 |
| `DelegateToAccountAccessPoints` | Allow | Lets access points owned by this account make the decision | T08 |

The encryption rule uses two conditions together. `StringNotEquals` on the header catches someone asking for `AES256`. The `Null: false` part means it only applies when the header is present, so uploads with no header still go through and pick up the bucket default, which is SSE-KMS anyway (T07 checks that).

Every Deny has a condition. A Deny on `s3:*` for `Principal: *` with no condition locks out everyone, admins included; only the root user can delete the policy at that point.

## How we tested it

```bash
aws s3 cp data/products.csv s3://$DATA_BUCKET/public/test.csv --sse AES256   # AccessDenied
aws s3 cp data/products.csv s3://$DATA_BUCKET/public/test.csv                # works, ends up aws:kms
aws s3api list-objects-v2 --bucket $DATA_BUCKET \
  --endpoint-url http://s3.us-east-1.amazonaws.com                           # AccessDenied
```

## Two more examples we designed but didn't apply

**Only one role may touch `restricted/`:**

```json
{
  "Sid": "RestrictedPrefixOnlyForPaymentsRole",
  "Effect": "Deny",
  "Principal": "*",
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "arn:aws:s3:::dp-lab-data-<suffix>/restricted/*",
  "Condition": {
    "ArnNotEquals": { "aws:PrincipalArn": "arn:aws:iam::<account>:role/dp-lab-payments-role" }
  }
}
```

Even administrators would be denied. In real use you'd add a break-glass role to the exception. We didn't apply it because our deploy script uploads to `restricted/` as the admin role.

**Only from inside our VPC:**

```json
{
  "Sid": "DenyUnlessFromVpcEndpoint",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": ["arn:aws:s3:::dp-lab-data-<suffix>", "arn:aws:s3:::dp-lab-data-<suffix>/*"],
  "Condition": { "StringNotEquals": { "aws:SourceVpce": "<vpce-id>" } }
}
```

Stolen credentials used from the internet would be useless. It also blocks the console and CloudShell, which is why it stays on paper for this lab. See [data-in-transit.md](../week-3-tls-secrets/data-in-transit.md).
