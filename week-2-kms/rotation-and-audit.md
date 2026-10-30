# Key rotation and audit plan

Deliverable 11. Owner: Ammar

## Rotation

Rotation gives a key new key material. The old material is kept, so anything encrypted before still decrypts, and the key ID and ARN stay the same, so nothing that uses the key has to change.

| Key | Rotation | Policy review | Alert | Before deleting |
|---|---|---|---|---|
| `dp-lab-s3` | automatic, 365 days | quarterly | yes | bucket emptied |
| `dp-lab-db` | automatic, 365 days | quarterly | yes | table and RDS deleted |
| `dp-lab-ebs` | automatic, 365 days | quarterly | yes | volumes and snapshots deleted, EBS default reset |
| `dp-lab-secrets` | automatic, 365 days | quarterly | yes | secrets and SecureStrings deleted |
| `dp-lab-demo` | automatic, 365 days + on demand in the lab | - | yes | nothing depends on it |

Owner of all five: Ammar. Rotation can be set anywhere from 90 to 2560 days; a year is the common default and matches what we were asked for.

## Audit

| What | How | Who | How often |
|---|---|---|---|
| Who used which key | CloudTrail event history, source `kms.amazonaws.com` (Decrypt, GenerateDataKey, CreateGrant ...). Test T28 | Ammar | weekly in the lab, monthly in production |
| Dangerous changes | EventBridge rule `dp-lab-kms-critical-changes` emails the team on `DisableKey`, `ScheduleKeyDeletion`, `PutKeyPolicy` | everyone | as it happens |
| Policies and grants | `get-key-policy`, `list-grants`, compared with [key-policy.md](key-policy.md) | Ammar + lead | quarterly |
| Rotation still on | test T12 | Ammar | quarterly |

The rule is in [01-kms.yaml](../infra/01-kms.yaml):

```yaml
EventPattern:
  source: [aws.kms]
  detail-type: [AWS API Call via CloudTrail]
  detail:
    eventSource: [kms.amazonaws.com]
    eventName: [DisableKey, ScheduleKeyDeletion, PutKeyPolicy]
```

It relies on CloudTrail management events, which `dp-lab-trail` records.

## If a key is compromised

1. **Disable** it. Everything stops, and it can be undone.
2. **Find out** from CloudTrail who used it, from where, and what they decrypted.
3. **Re-encrypt** the data under a new key: S3 copy in place, RDS snapshot copy with the new key, and so on.
4. **Fix** the key policy and grants; rotate any credentials involved.
5. **Schedule deletion** of the old key (7 to 30 days) once nothing depends on it.
6. Write it up in the risk register.
