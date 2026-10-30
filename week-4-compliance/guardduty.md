# GuardDuty (threats to our data)

Part of deliverable 17. Owner: Ahmed Ali

GuardDuty is on with S3 Protection (`S3_DATA_EVENTS`), which watches S3 data-plane activity such as GetObject and PutObject. It's in [05-detection.yaml](../infra/05-detection.yaml) and checked by T27.

A brand new lab with four users won't produce real findings, so we generate **sample** findings with [scripts/guardduty-samples.sh](../scripts/guardduty-samples.sh). The console marks them `[SAMPLE]`. They are not incidents and we don't present them as such.

| Finding type | Severity | What it means | What we'd do | What already reduces the risk |
|---|---|---|---|---|
| `Policy:S3/BucketBlockPublicAccessDisabled` | Low | someone turned off Block Public Access on a bucket | turn it back on, find who in CloudTrail | account-level BPA (T03), Access Analyzer |
| `Exfiltration:S3/AnomalousBehavior` | High | a principal is reading objects in an unusual way or volume | revoke their sessions, disable the credentials, scope it with CloudTrail and access logs, decide on breach notification | least privilege, access point, key policy limits who can decrypt |
| `Discovery:S3/MaliciousIPCaller` | High | S3 APIs called from a known malicious IP | revoke/rotate the credentials used, investigate | MFA, no long-term keys, CloudShell only |
| `UnauthorizedAccess:S3/TorIPCaller` | Medium | S3 APIs called from a Tor exit node | same; consider `aws:SourceIp` or VPC endpoint conditions | TLS-only bucket policy, VPC endpoint design |

## Alerts

`dp-lab-guardduty-high` sends findings with severity 7 or more to `dp-lab-security-alerts`:

```yaml
EventPattern:
  source: [aws.guardduty]
  detail-type: [GuardDuty Finding]
  detail:
    severity: [{ numeric: [">=", 7] }]
```

## Not done

Security Hub with the AWS Foundational Security Best Practices standard would give a scored list of misconfigurations across the account. It's a good next step; we left it out to keep the cost and the scope down.
