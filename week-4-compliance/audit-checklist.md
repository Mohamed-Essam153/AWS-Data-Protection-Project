# Audit readiness checklist

Owner: Ahmed Ali. Go through this before the final report and again before the demo.

- [ ] Latest full test run committed in `evidence/`, no unexplained FAIL
- [ ] Every compliance matrix row points at a test ID or a file that exists
- [ ] Screenshots in `evidence/screenshots/` match the list there; account IDs and emails blurred
- [ ] Every policy we talk about is in a template in `infra/`, not only in a screenshot
- [ ] CloudTrail log file validation on (T01) and KMS events visible (T28)
- [ ] Access review done twice, with reviewer and date filled in
- [ ] Risk register owners and statuses filled; accepted risks explained
- [ ] GitHub secret scanning shows no alerts
- [ ] Anything design-only says "design only" in the matrix and the docs
- [ ] Wording says "mapped to", never "compliant with"
- [ ] Article, section and requirement numbers checked against the sources: [GDPR](https://eur-lex.europa.eu/eli/reg/2016/679/oj/eng), [HIPAA Security Rule, 45 CFR 164 Subpart C](https://www.ecfr.gov/current/title-45/subtitle-A/subchapter-C/part-164/subpart-C), [PCI DSS v4.0.1](https://www.pcisecuritystandards.org/document_library/)
