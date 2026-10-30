# How we worked

## Plan

Four weeks after a short kickoff. Everyone works every week; the "owner" is the person who leads that week's deliverables.

| Week | Ahmed Ali | Ahmed Shaaban | Ammar | Mohamed Essam |
|---|---|---|---|---|
| Kickoff | Account, Identity Center + MFA, budget, CloudTrail, repo | Fake data generator | List of keys | Sketch the demo API |
| 1 | Matrix and risk register templates, architecture v1 | **S3 and classification** | KMS stack early so S3 can use it | Lambda skeleton |
| 2 | Matrix rows for week 1 | Access review, re-check S3 | **KMS and data stores** | Cognito, Parameter Store |
| 3 | Macie and GuardDuty stack | Compare Macie results with our classification | Secrets key, key alarm | **TLS, secrets, API** |
| 4 | **Compliance and final report** | Week 1 report section | Week 2 report section | Week 3 report section |

## Responsibilities (RACI)

R = does it, A = signs it off, C = consulted, I = kept informed

| Activity | Ahmed Ali | A. Shaaban | Ammar | M. Essam |
|---|---|---|---|---|
| Account and repo setup | R/A | I | I | I |
| Fake data | A | R | I | I |
| Classification and S3 | A | R | C | I |
| KMS and encryption at rest | A | C | R | C |
| Demo API | A | I | C | R |
| TLS, secrets, API protection | A | I | C | R |
| Macie, GuardDuty, DLP | R/A | C | I | I |
| Compliance matrix, risk register | R/A | C | C | C |
| Final report and demo | R/A | C | C | C |
| Teardown | A | R | R | R |

## Git

- `main` is protected: pull request + one approval.
- Branch per piece of work: `week-1/s3-baseline`, `week-2/kms-keys`, ...
- Secret scanning and push protection on in the repo settings.
- Before approving, the reviewer checks the diff for account IDs, emails, tokens.

## Weekly review (Thursday)

- [ ] The week's tests pass in a fresh run, report committed
- [ ] Docs updated to match what is deployed
- [ ] Nothing sensitive in the diff
- [ ] Everything new carries the Owner / Environment / Project tags (Tag Editor)
- [ ] Spend vs budget checked; paid options switched off if not needed next week
- [ ] Compliance matrix rows filled for the week
- [ ] New risks added to the register
