# Data handling standard

Deliverable 6. Owner: Ahmed Shaaban. Uses the levels from [data-classification.md](data-classification.md) and the retention from [lifecycle-policy.md](lifecycle-policy.md).

| | Public | Internal | Confidential | Restricted |
|---|---|---|---|---|
| **Where** | `public/` | `internal/` | `confidential/`, DynamoDB/RDS on `dp-lab-db` | `restricted/` only |
| **Encryption at rest** | SSE-KMS (bucket default) | SSE-KMS `dp-lab-s3` | customer managed key | customer managed key, Macie watching |
| **Who** | anyone on the team; publishing needs owner OK | staff; analytics through the access point | named roles, need to know, every access logged | named roles only, reviewed every quarter |
| **Sharing** | after owner approval | internal teams, access point or presigned URL up to 1 hour | only under a data-sharing agreement, never as an email attachment | not without security and legal sign-off |
| **In transit** | HTTPS | TLS 1.2+ | TLS 1.2+, no personal data in URLs, logs or API responses | TLS 1.2+, private network path in production |
| **Keep for** | until replaced | 365 days | set by the owner | 180 days |
| **Disposal** | delete | lifecycle expiry + old versions expired | delete + key deletion when the store is retired | lifecycle expiry, crypto-shredding |
| **If it leaks** | tell the owner | tell the team lead within 24h | incident process; consider GDPR Art. 33 (72 hours) | incident process now; GDPR / HIPAA breach notification and PCI incident steps |

Incident contact for the lab: Ahmed Ali, through the `dp-lab-security-alerts` SNS topic.
