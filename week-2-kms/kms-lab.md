# KMS lab

Deliverable 10. Owner: Ammar. Uses `alias/dp-lab-demo` only. Automated as test T13; the steps below are the same thing by hand.

## 1. Encrypt and decrypt directly

```bash
echo "Fake card 4111-1111-1111-1111 for the KMS lab" > plain.txt
aws kms encrypt --key-id alias/dp-lab-demo --plaintext fileb://plain.txt \
  --query CiphertextBlob --output text | base64 --decode > cipher.bin
od -An -tx1 -N32 cipher.bin           # unreadable
aws kms decrypt --ciphertext-blob fileb://cipher.bin \
  --query Plaintext --output text | base64 --decode
```

Why doesn't `decrypt` need a key ID? The ciphertext blob carries metadata that tells KMS which key made it. Passing `--key-id` anyway is still good practice, so a ciphertext made with some other key fails instead of quietly decrypting.

## 2. A data key (envelope encryption)

```bash
aws kms generate-data-key --key-id alias/dp-lab-demo --key-spec AES_256 \
  --query '{EncryptedCopy: CiphertextBlob}'
```

The response also contains the plaintext key. That one is for encrypting locally and then forgetting; we only print the encrypted copy. This is what S3, DynamoDB and EBS do for us behind the scenes, see [key-hierarchy.md](key-hierarchy.md).

## 3. Disable the key

```bash
DEMO=$(aws kms describe-key --key-id alias/dp-lab-demo --query KeyMetadata.KeyId --output text)
aws kms disable-key --key-id $DEMO
aws kms decrypt --ciphertext-blob fileb://cipher.bin      # DisabledException
aws kms enable-key --key-id $DEMO
rm plain.txt cipher.bin
```

(`disable-key` and `enable-key` want the key ID, not the alias.)

Disabling stops every cryptographic use right away and can be undone. Deleting cannot: after the waiting period everything encrypted under the key is gone for good. Used on purpose, that's crypto-shredding.

Disabling also triggers the `dp-lab-kms-critical-changes` EventBridge rule, so an email arrives within a minute or two. Screenshot it: `W2-03-kms-alarm-email.png`.

Only ever do this to the demo key. Disabling `dp-lab-s3` or `dp-lab-db` would break the bucket and the table.

## 4. Grants

A grant gives one principal narrow, temporary use of a key without touching the key policy. AWS services use them all the time (that's what `AllowGrantsForAWSResources` is for).

```bash
ROLE=$(aws iam get-role --role-name dp-lab-analytics-role --query Role.Arn --output text)
GRANT=$(aws kms create-grant --key-id $DEMO --grantee-principal $ROLE \
  --operations Encrypt Decrypt GenerateDataKey --name lab-grant --query GrantId --output text)
aws kms list-grants --key-id $DEMO --query 'Grants[].{Name:Name,Ops:Operations}'
aws kms revoke-grant --key-id $DEMO --grant-id $GRANT
```

Assume the analytics role between the create and the revoke and `kms encrypt` works; after the revoke it gets AccessDenied.

## 5. Rotation

```bash
aws kms get-key-rotation-status --key-id $DEMO
aws kms rotate-key-on-demand    --key-id $DEMO
aws kms list-key-rotations      --key-id $DEMO
```

The on-demand rotation shows up in `list-key-rotations` immediately. All five keys also rotate automatically every 365 days (T12).
