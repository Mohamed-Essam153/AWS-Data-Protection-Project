# AWS Data Protection, Encryption & Privacy Compliance

DEPI graduation project, Cloud Security track.

We built a small but complete data protection setup on AWS and wrote it as code, so anyone can deploy it, test it and tear it down again. It covers the whole life of a piece of data: classifying it, storing it in S3 with tight policies, encrypting it with our own KMS keys, protecting it on the way in and out (TLS, secrets, a locked-down API), and finally finding it when it ends up in the wrong place (Macie, GuardDuty). Every control is mapped to GDPR, HIPAA and PCI DSS and has a test that proves it works.

All data in the lab is fake, generated with Faker.

![Architecture](architecture/main-architecture.png)

## Team

| Member | Area |
|---|---|
| Ahmed Ali (lead) | Account setup, CloudTrail, detection (Macie, GuardDuty), DLP, compliance mapping, final report |
| Ahmed Shaaban | Data lifecycle, classification, S3 security, access reviews |
| Ammar | KMS key design, key policies, rotation, encrypted data stores |
| Mohamed Essam Elbastawisy | Demo API, TLS, secrets management, API protection, data in transit |

## Quick start

You need an AWS account where you can sign in through IAM Identity Center (see [week 0](week-0-setup/account-setup.md)). Everything else runs in AWS CloudShell.

```bash
git clone https://github.com/Mohamed-Essam153/AWS-Data-Protection-Project.git
cd AWS-Data-Protection-Project
cp config.example.env config.env      # set SUFFIX, ALERT_EMAIL, OWNER
./scripts/deploy.sh                   # ~10 minutes the first time
./tests/run-tests.sh                  # writes evidence/test-report-<time>.md
```

When you are done: `./scripts/teardown.sh`. More detail in [docs/deployment.md](docs/deployment.md).

## What gets deployed

| Stack | Template | Contents |
|---|---|---|
| `dp-lab-foundation` | [00-foundation.yaml](infra/00-foundation.yaml) | CloudTrail (log file validation), SNS alerts topic, Lambda artifacts bucket, monthly budget |
| `dp-lab-kms` | [01-kms.yaml](infra/01-kms.yaml) | 5 customer managed keys with yearly rotation, key policies, alert on key changes |
| `dp-lab-s3` | [02-s3.yaml](infra/02-s3.yaml) | Data bucket + logs bucket, bucket policy, lifecycle rules, analytics access point, Access Analyzer |
| `dp-lab-datastores` | [03-datastores.yaml](infra/03-datastores.yaml) | DynamoDB on our own key, optional RDS PostgreSQL with forced TLS |
| `dp-lab-app` | [04-app.yaml](infra/04-app.yaml) | REST API (TLS 1.2+ policy, Cognito, throttling, access logs), Lambda, Secrets Manager, optional WAF |
| `dp-lab-detection` | [05-detection.yaml](infra/05-detection.yaml) | Macie with a custom identifier, GuardDuty S3 Protection, alert rules |

A few settings have no CloudFormation resource (account-level Block Public Access, EBS default encryption, SecureString parameters). [scripts/deploy.sh](scripts/deploy.sh) and [scripts/post-deploy.sh](scripts/post-deploy.sh) handle those.

RDS, WAF, Macie and GuardDuty cost money, so they are off by default. Switch them on in `config.env` for the week that needs them and for the demo. See [docs/cost.md](docs/cost.md).

## Deliverables

| # | Deliverable | Where |
|---|---|---|
| 1 | Data classification scheme | [week-1-s3/data-classification.md](week-1-s3/data-classification.md) |
| 2 | S3 secure baseline | [week-1-s3/s3-baseline.md](week-1-s3/s3-baseline.md) |
| 3 | Bucket policy examples | [week-1-s3/bucket-policy.md](week-1-s3/bucket-policy.md) |
| 4 | Access review | [week-1-s3/access-review.md](week-1-s3/access-review.md) |
| 5 | Lifecycle policy | [week-1-s3/lifecycle-policy.md](week-1-s3/lifecycle-policy.md), [data-lifecycle.md](week-1-s3/data-lifecycle.md) |
| 6 | Data handling standard | [week-1-s3/data-handling-standard.md](week-1-s3/data-handling-standard.md) |
| 7 | KMS key hierarchy | [week-2-kms/key-hierarchy.md](week-2-kms/key-hierarchy.md) |
| 8 | Key policy design | [week-2-kms/key-policy.md](week-2-kms/key-policy.md) |
| 9 | Encrypted data stores | [week-2-kms/encrypted-data-stores.md](week-2-kms/encrypted-data-stores.md) |
| 10 | KMS lab | [week-2-kms/kms-lab.md](week-2-kms/kms-lab.md) |
| 11 | Key rotation and audit plan | [week-2-kms/rotation-and-audit.md](week-2-kms/rotation-and-audit.md), [cloudhsm-vs-kms.md](week-2-kms/cloudhsm-vs-kms.md) |
| 12 | TLS setup | [week-3-tls-secrets/tls.md](week-3-tls-secrets/tls.md) |
| 13 | Certificate inventory | [week-3-tls-secrets/certificate-inventory.md](week-3-tls-secrets/certificate-inventory.md) |
| 14 | Secrets rotation design | [week-3-tls-secrets/secrets.md](week-3-tls-secrets/secrets.md) |
| 15 | API security controls | [week-3-tls-secrets/api-security.md](week-3-tls-secrets/api-security.md) |
| 16 | Data-in-transit architecture | [week-3-tls-secrets/data-in-transit.md](week-3-tls-secrets/data-in-transit.md), [vpn-ipsec.md](week-3-tls-secrets/vpn-ipsec.md) |
| 17 | Macie findings report | [week-4-compliance/macie-report.md](week-4-compliance/macie-report.md), [guardduty.md](week-4-compliance/guardduty.md) |
| 18 | DLP plan | [week-4-compliance/dlp-plan.md](week-4-compliance/dlp-plan.md) |
| 19 | Compliance control matrix | [week-4-compliance/compliance-matrix.xlsx](week-4-compliance/compliance-matrix.xlsx) |
| 20 | Risk register | [week-4-compliance/risk-register.xlsx](week-4-compliance/risk-register.xlsx) |
| 21 | Final report | [final-report/README.md](final-report/README.md) |

## Repository layout

```
infra/          CloudFormation templates, one per stack
app/            Lambda handler for the demo API
scripts/        deploy, post-deploy, teardown and helper scripts
tests/          live tests (run-tests.sh) and unit tests for the Lambda
tools/          fake data generator, link checker
week-*/         the written deliverables, grouped by week
evidence/       test reports and screenshots from our own runs
docs/           deployment, testing, demo, cost, teardown, troubleshooting
architecture/   diagrams (Graphviz sources + PNG)
```

## A couple of notes

- Controls are *mapped to* GDPR, HIPAA and PCI DSS. A lab with fake data isn't compliant or certified with anything, and we don't claim it is.
- Never commit `config.env`, account IDs, tokens or passwords. The test report redacts the account ID for you. [docs/evidence.md](docs/evidence.md) has the rules.
