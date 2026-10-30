# Key policy design

Deliverable 8. Owner: Ammar. Policies are inline in [01-kms.yaml](../infra/01-kms.yaml); the S3 key's is the fullest.

| Sid | Who | Can do | Why |
|---|---|---|---|
| `EnableIAMPolicies` | the account | `kms:*` | Lets IAM policies grant key access, and stops the key from becoming unmanageable. Never remove it |
| `KeyAdministrators` | `KeyAdminRoleArn` | create, describe, enable/disable, change policy, rotate, schedule deletion. **No encrypt or decrypt** | Separation of duties: whoever manages the key can't read the data |
| `KeyUsersCryptoOnly` | `KeyUserRoleArn` | Encrypt, Decrypt, ReEncrypt, GenerateDataKey, DescribeKey | Using the key without being able to change it |
| `AllowGrantsForAWSResources` | `KeyUserRoleArn` | Create/List/Revoke grants, **only when** `kms:GrantIsForAWSResource` is true | S3, RDS, EBS, DynamoDB need grants; a person can't hand out grants to arbitrary principals |
| `AllowMacieToDecrypt` (S3 key only) | Macie's service-linked role | Decrypt | Without it Macie can't read SSE-KMS objects ([AWS docs](https://docs.aws.amazon.com/macie/latest/user/discovery-supported-encryption-types.html)) |

## Two design choices worth explaining

**Macie's role is matched by condition, not named as principal.** The usual statement names `AWSServiceRoleForAmazonMacie` directly. That role only exists once Macie is enabled, and KMS rejects a policy naming a principal that doesn't exist. Since we deploy the keys first and Macie is optional, we use `Principal: *` with `aws:PrincipalArn` set to the role's ARN and `kms:CallerAccount` set to our account. Same effect, works in any order.

**Separation of duties is real only if the roles are different.** By default `deploy.sh` puts the signed-in role in both `KeyAdminRoleArn` and `KeyUserRoleArn`, and every one of us is an administrator anyway (risk R-05), so `EnableIAMPolicies` lets us do everything. To demonstrate it properly, create two permission sets (e.g. `DPLabKeyAdmin` with KMS management only, `DPLabKeyUser` with crypto only), put their role ARNs in `config.env`, redeploy, and show that the admin role gets AccessDenied on `kms:Decrypt`.

## Optional hardening

Restrict a key to one service with `kms:ViaService`. We do this in the IAM policies of the Lambda role and the analytics role, so even with their credentials you can't call `kms:Decrypt` directly on some stolen ciphertext:

```yaml
Condition:
  StringEquals:
    kms:ViaService: s3.us-east-1.amazonaws.com
```

## Rules

- Copy role ARNs exactly. Identity Center roles have a path: `.../role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_<name>_<hash>`.
- Never remove `EnableIAMPolicies` or all the administrators. Getting a key back after that needs AWS Support.
