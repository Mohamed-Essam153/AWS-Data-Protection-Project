# Final report

Deliverable 21. Owner: Ahmed Ali, with a section from each member.

The report is written from what's in this repo. Each member writes about two pages for their part, in the same shape: what we set out to do, what we built, how we tested it, what the evidence shows, what's missing.

| Section | Writer | Built from |
|---|---|---|
| 1. Summary: scope, results, top risks | Ahmed Ali | everything |
| 2. Scope, environment, shared responsibility | Ahmed Ali | [README](../README.md), [week 0](../week-0-setup/account-setup.md), [AWS shared responsibility model](https://aws.amazon.com/compliance/shared-responsibility-model/) |
| 3. Architecture | Ahmed Ali, Mohamed | [architecture/](../architecture/) |
| 4. Lifecycle, classification, S3 | Ahmed Shaaban | [week-1-s3/](../week-1-s3/) |
| 5. Encryption at rest and key management | Ammar | [week-2-kms/](../week-2-kms/) |
| 6. Encryption in transit, secrets, API | Mohamed Essam | [week-3-tls-secrets/](../week-3-tls-secrets/) |
| 7. Discovery, threat detection, DLP | Ahmed Ali | [week-4-compliance/](../week-4-compliance/) |
| 8. Compliance mapping and risks | Ahmed Ali | [compliance-matrix.xlsx](../week-4-compliance/compliance-matrix.xlsx), [risk-register.xlsx](../week-4-compliance/risk-register.xlsx) |
| 9. Limits and what production would need | all | below |
| Appendix A: test results | all | latest report in [evidence/](../evidence/) |
| Appendix B: templates and policies | all | [infra/](../infra/) |
| Appendix C: teardown | all | [docs/teardown.md](../docs/teardown.md) |

When it's done, export it as a PDF and add it to this folder.

## Limits we state up front

- Fake data, one account, four weeks. Controls are mapped to GDPR, HIPAA and PCI DSS; nothing is certified.
- Everyone on the team had AdministratorAccess (R-05).
- CloudHSM, VPN, Direct Connect and VPC interface endpoints are designs only.
- GuardDuty findings are AWS samples.
- No custom domain, so ACM is described but not attached.
- The third-party key's rotation Lambda is designed, not built.

## What production would add

AWS Organizations with SCPs; one permission set per job instead of admin for all; a separate logging account; data paths through VPC endpoints; automated Macie discovery; Security Hub and AWS Config conformance packs; rotation Lambdas for every secret; policy checks (cfn-lint, cfn-guard) in a CI pipeline before anything deploys.
