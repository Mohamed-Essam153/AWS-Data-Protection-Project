# Macie findings report

Deliverable 17. Owner: Ahmed Ali

## Setup

| | |
|---|---|
| Bucket | `dp-lab-data-<suffix>` |
| Job | one-time, 100% sampling, started by [scripts/run-macie-job.sh](../scripts/run-macie-job.sh) |
| Managed identifiers | AWS recommended set |
| Custom identifier | `EmployeeID`, regex `EMP-\d{6}`, keywords `emp_id`, `employee` ([05-detection.yaml](../infra/05-detection.yaml)) |
| KMS | `AllowMacieToDecrypt` in the S3 key policy, so SSE-KMS objects can be read |
| Alerts | `dp-lab-macie-findings` rule sends findings to `dp-lab-security-alerts` |

```bash
# ENABLE_MACIE=true in config.env, then:
./scripts/deploy.sh
./scripts/run-macie-job.sh          # 10-20 minutes
./scripts/macie-findings.sh         # table + evidence/macie-findings-<time>.md
```

## What we expect, and what to compare against

This is what our classification says each file should contain. Put the actual results from `macie-findings.sh` in the last two columns.

| Object | We labelled it | Should contain | Macie found | Match |
|---|---|---|---|---|
| `restricted/payments.csv` | Restricted | card numbers, names | | |
| `restricted/patients.csv` | Restricted | US SSNs, names | | |
| `confidential/customers.csv` | Confidential | emails, phones, addresses, names, dates of birth | | |
| `internal/staff-directory.csv` | Internal | EmployeeID (custom), names, emails | | |
| `internal/notes-export.csv` | Internal | **nothing sensitive, supposedly** | | |
| `public/products.csv` | Public | nothing | | |

## The interesting one

`internal/notes-export.csv` is the file we planted in week 0: support notes where someone pasted customers' card numbers. Its label says Internal. Macie should report credit card numbers in it, which means it's really Restricted data sitting in a place the analytics role can read.

That's the point of this week: a classification scheme only works if people apply it correctly, and Macie is how you find out when they didn't.

## What we did about it

[scripts/remediate-misclassified.sh](../scripts/remediate-misclassified.sh):

1. Moves it to `restricted/notes-export.csv` and tags it `DataClassification=Restricted`
2. Deletes the versions left under `internal/` (otherwise versioning would keep a readable copy there)
3. Pulls S3 access logs and lists who read it under `internal/` (logs can lag a few hours)

Then: note it as R-01 in the risk register, tell the data owner, and re-run the job to confirm `internal/` is clean.

## Bucket-level view

Macie's S3 summary for the bucket should show: not public, not shared outside the account, default encryption SSE-KMS. Screenshot `W4-01-macie-findings.png`.

## For production

- Automated sensitive data discovery instead of one-off jobs
- Findings into a ticketing system, not only email
- Custom identifiers for our own formats (customer IDs, case numbers)
