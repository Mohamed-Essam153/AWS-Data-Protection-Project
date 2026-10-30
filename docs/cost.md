# Cost

Rough numbers for a lab of this size. Prices change and differ by region, so check the AWS pricing page for each service before you turn the paid parts on. The budget in `dp-lab-foundation` emails you at 50%, 80% and 100% of `MONTHLY_BUDGET_USD`.

| Service | What we pay for | Notes |
|---|---|---|
| KMS | ~$1 per key per month, prorated, plus requests | 5 keys. Bucket Keys keep request counts low ([AWS docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html)) |
| Secrets Manager | ~$0.40 per secret per month | 1 secret (2 with RDS) |
| Parameter Store | free (standard tier) | |
| S3, DynamoDB on-demand, Lambda, API Gateway, CloudTrail (first trail) | cents at our volume | |
| RDS (`ENABLE_RDS`) | per hour while it exists | free tier may cover a `db.t4g.micro` on a new account; turn off when not needed |
| WAF (`ENABLE_WAF`) | monthly per web ACL and per rule, prorated, plus requests | on for week 3 and the demo only |
| Macie (`ENABLE_MACIE`) | free trial, then per bucket and per GB scanned | our bucket is tiny |
| GuardDuty (`ENABLE_GUARDDUTY`) | free trial, then by events analysed | |

Things we deliberately did **not** create: CloudHSM, Site-to-Site VPN, AWS Private CA, interface VPC endpoints. They bill by the hour or have a high monthly price, so they are covered as design only.

Rule of thumb from the plan: keep the whole thing under $20/month and tear it down after the demo.
