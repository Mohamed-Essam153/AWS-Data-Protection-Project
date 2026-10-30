# Demo plan (about 15 minutes)

Order: architecture, S3, KMS, API, detection, compliance. Everything runs live from CloudShell; keep screenshots from `evidence/` open in another tab in case the network misbehaves.

## The day before

- `ENABLE_WAF=true`, `ENABLE_MACIE=true`, `ENABLE_GUARDDUTY=true` in `config.env`, then `./scripts/deploy.sh`
- Run the Macie job (`./scripts/run-macie-job.sh`) - it takes 10-20 minutes, so not on stage
- `./scripts/guardduty-samples.sh`
- Full rehearsal twice, then wait 5 minutes so the WAF rate counter resets

## Running order

| Time | Who | What to show |
|---|---|---|
| 0-2 | Ahmed Ali | Goal, [architecture diagram](../architecture/main-architecture.png), shared responsibility, who did what |
| 2-5 | Ahmed Shaaban | Classification levels, bucket settings, `./tests/run-tests.sh T05 T08` (wrong encryption denied, access point allow/deny) |
| 5-8 | Ammar | `./tests/run-tests.sh T07 T13` (object is `aws:kms`, disabled key can't decrypt), key policy in the console, the alarm email arriving |
| 8-11 | Mohamed Essam | `./tests/run-tests.sh T20 T22 T23 T25 T24` (TLS policy, 401, 200, 429, 403), secret versions with `T18` |
| 11-14 | Ahmed Ali | Macie finding on `internal/notes-export.csv` and `./scripts/remediate-misclassified.sh`, GuardDuty samples, compliance matrix, top risks |
| 14-15 | Ahmed Ali | Limitations, what production would add, questions |

Running the test IDs instead of raw commands keeps the output short and readable on a projector. If someone asks "what does that actually run?", open [tests/run-tests.sh](../tests/run-tests.sh) and show the block.

## After the demo

Commit the final test report, then follow [teardown.md](teardown.md).
