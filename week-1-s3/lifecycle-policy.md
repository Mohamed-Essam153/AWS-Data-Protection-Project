# Lifecycle policy

Deliverable 5. Owner: Ahmed Shaaban. Rules are in `DataBucket > LifecycleConfiguration` in [02-s3.yaml](../infra/02-s3.yaml).

| Rule | Applies to | What happens | Why |
|---|---|---|---|
| `archive-internal` | `internal/` | Standard-IA at 30 days, Glacier at 90, deleted at 365 | Internal files lose value fast; a year covers operational needs |
| `restricted-short-retention` | `restricted/` | Glacier at 90 days, deleted at 180 | Data minimisation: GDPR Art. 5(1)(e), and PCI DSS asks to keep cardholder data only as long as there is a business need (req. 3.2) |
| `cleanup-old-versions-and-uploads` | whole bucket | Noncurrent versions deleted after 30 days, incomplete multipart uploads aborted after 7 | So versioning doesn't quietly keep deleted data forever, and partial uploads don't pile up |

`public/` and `confidential/` have no automatic expiry here. For real customer data the owner would set a retention period (customer relationship plus whatever the law requires) and we'd add a rule for it.

Nothing will actually transition during a four-week lab, and S3 doesn't move very small objects to IA by default. The configuration itself is the evidence: T10 in the test report and screenshot `W1-03-lifecycle.png`.

```bash
aws s3api get-bucket-lifecycle-configuration --bucket $DATA_BUCKET
```
