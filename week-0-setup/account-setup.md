# Week 0 - Account setup

Owner: Ahmed Ali (fake data: Ahmed Shaaban)

Most of the account is built by the templates, but a few things have to be done by hand before the first deploy, mainly because they involve the root user or people.

## 1. Root user

1. Sign in as root once. **Security credentials**: assign an MFA device.
2. Make sure there are no root access keys. Delete any you find.
3. Sign out. Root is not used again except for emergencies.

Evidence: screenshot `W0-01-root-mfa.png` (MFA assigned, no access keys).

## 2. IAM Identity Center

1. **IAM Identity Center > Enable** (same region as the lab).
2. **Users**: one per team member. **Groups**: `DPLabTeam` with all four.
3. **Permission sets > Create**: predefined `AdministratorAccess`, session duration 4 hours, name `DPLabAdmin`.
4. **AWS accounts**: assign `DPLabTeam` with `DPLabAdmin`.
5. **Settings > Authentication > Multi-factor authentication**: require MFA on every sign-in, and require users to register a device if they don't have one.
6. Everyone signs in through the access portal URL and registers MFA.

Evidence: `W0-02-identity-center-users.png`, `W0-02-mfa-setting.png`.

AdministratorAccess for all four of us is more than least privilege. We accepted that for a four-week lab with MFA, CloudTrail, short sessions, a budget alert and a teardown at the end. It is risk R-05 in the [risk register](../week-4-compliance/risk-register.xlsx). In a real environment each of us would get a permission set scoped to the services we work on.

## 3. Everything else is code

The rest of week 0 is in [00-foundation.yaml](../infra/00-foundation.yaml):

| Item | Resource |
|---|---|
| Budget with 50/80/100% alerts | `MonthlyBudget` |
| CloudTrail, all regions, log file validation on | `Trail`, `TrailBucket` |
| Where alerts go | `AlertsTopic` + email subscription |

Region: `us-east-1`. Naming: `dp-lab-<what>`, buckets get the team suffix. Every resource is tagged `Owner`, `Environment=Lab`, `Project=DataProtection` by `deploy.sh`; data resources also carry `DataClassification`.

Checked by tests T01 (CloudTrail) and T02 (budget).

## 4. Repository

- Branch protection on `main` (PR + 1 approval)
- Secret scanning and push protection turned on
- [.gitignore](../.gitignore) keeps out `config.env`, generated data and key material

## 5. Fake data

[tools/generate_fake_data.py](../tools/generate_fake_data.py) writes six CSV files with Faker (seeded, so the same every time):

| File | Classification | What's in it |
|---|---|---|
| `products.csv` | Public | SKUs, prices |
| `staff-directory.csv` | Internal | employee IDs (`EMP-123456`), names, work emails |
| `customers.csv` | Confidential | names, emails, phones, addresses, dates of birth |
| `payments.csv` | Restricted | card numbers, expiry, IBAN |
| `patients.csv` | Restricted | SSNs, diagnoses |
| `notes-export.csv` | looks Internal | support notes with card numbers pasted in. This is the mistake Macie has to find in week 4 |

`post-deploy.sh` runs the generator and uploads the files. The `data/` folder is git-ignored.
