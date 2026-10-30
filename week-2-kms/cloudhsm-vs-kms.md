# CloudHSM vs KMS

Part of deliverable 11. Owner: Ammar. Not provisioned: CloudHSM bills per HSM per hour, far beyond a lab budget.

| | AWS KMS | AWS CloudHSM |
|---|---|---|
| What it is | Managed key service, shared infrastructure | HSMs dedicated to you, inside your VPC |
| Who runs the HSMs | AWS. You control keys through key policies | You manage HSM users, keys, backups and the cluster |
| Integrations | Built into S3, RDS, EBS, DynamoDB, Secrets Manager and most other services | PKCS#11, JCE, OpenSSL engine; or behind KMS as a custom key store |
| Availability | Built in | You run at least two HSMs in different AZs |
| Price | about $1 per key per month plus requests | per HSM per hour |
| When to use | Almost always | A regulator or contract requires single-tenant HSMs under your exclusive control, you need algorithms or operations KMS doesn't offer, or SSL/TLS offload |
| FIPS 140 validation | check the current certificate on AWS's compliance pages | check the current certificate on AWS's compliance pages |

FIPS levels and certificate numbers change as AWS re-validates, so we left them out rather than quote a number that might be out of date. Look them up the week you write the final report and put the date next to them.

## Decision

KMS. Every store we use integrates with it natively, every use is in CloudTrail, and key policies give us the separation of duties we need. We'd revisit only if someone required dedicated HSMs, and even then the first step would be a KMS custom key store backed by CloudHSM, so the services keep working the same way.
