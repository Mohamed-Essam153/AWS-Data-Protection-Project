# Screenshots

The test reports cover almost everything. These are the few things worth a picture, because they are console-only or because a reviewer will want to see them. Take them from your own account, blur the account ID and emails, and save them here with these names.

| File | Show |
|---|---|
| `W0-01-root-mfa.png` | Root user security credentials: MFA assigned, no access keys |
| `W0-02-identity-center-users.png` | Identity Center users and the DPLabTeam group |
| `W0-02-mfa-setting.png` | Identity Center MFA: required on every sign-in |
| `W0-03-stacks.png` | CloudFormation console with the six `dp-lab-*` stacks in `CREATE_COMPLETE` / `UPDATE_COMPLETE` |
| `W1-01-bucket-properties.png` | Data bucket Properties: versioning, default encryption, access logging |
| `W1-02-bucket-permissions.png` | Data bucket Permissions: Block Public Access, Object Ownership, bucket policy |
| `W1-03-lifecycle.png` | Data bucket Management: the three lifecycle rules |
| `W1-04-access-analyzer.png` | Access Analyzer with no active findings |
| `W2-01-kms-keys.png` | Customer managed keys list with the five `dp-lab-*` aliases |
| `W2-02-key-policy.png` | `dp-lab-s3` key policy |
| `W2-03-kms-alarm-email.png` | The email from the `dp-lab-kms-critical-changes` rule (sent during T13) |
| `W2-04-cloudtrail-kms.png` | CloudTrail Event history filtered on `kms.amazonaws.com` |
| `W3-01-api-authorizer.png` | API Gateway: Cognito authorizer on `GET /customer` |
| `W3-02-api-security-policy.png` | API settings showing the TLS 1.2+ security policy |
| `W3-03-secret-versions.png` | Secrets Manager secret, Versions tab (no values) |
| `W3-04-waf.png` | WAF web ACL with the three rules and its association |
| `W4-01-macie-findings.png` | Macie findings, including `internal/notes-export.csv` |
| `W4-02-guardduty-samples.png` | GuardDuty sample findings (marked SAMPLE) |
| `W4-03-secret-scanning.png` | GitHub secret scanning with no alerts |
