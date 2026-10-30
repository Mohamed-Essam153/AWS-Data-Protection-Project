# Data classification scheme

Deliverable 1. Owner: Ahmed Shaaban

## Levels

| Level | Meaning | Examples in our data | Minimum controls |
|---|---|---|---|
| Public | Fine for anyone to see | `products.csv` | Integrity (versioning). Still not in a public bucket in this lab |
| Internal | Staff only, low harm if it leaks | `staff-directory.csv` | Authenticated access, encryption at rest |
| Confidential | Personal data. Real harm to people or to us if it leaks | `customers.csv` | SSE-KMS, need-to-know access, logged, TLS only |
| Restricted | Regulated: payment cards, health data, national IDs | `payments.csv`, `patients.csv` | Dedicated key, named roles only, Macie watching it, shortest retention |

## Who decides

The data owner, meaning the team that creates or receives the data, picks the level when the data is created. If they aren't sure, they pick the higher one. Security checks the result with Macie (week 4).

## How the label is applied

Three places, so it survives being copied around:

1. **Prefix**: objects live under `public/`, `internal/`, `confidential/`, `restricted/` (and `archive/` for old restricted data). Policies and lifecycle rules key off the prefix.
2. **Object tag**: `DataClassification=<level>` on every object. [post-deploy.sh](../scripts/post-deploy.sh) sets it on upload.
3. **Resource tag**: every data store carries `DataClassification` for the highest level it holds. The data bucket is `Restricted`, the DynamoDB table `Confidential`.

Checked by T11 in the test report.

## Changing a classification

1. Something triggers it: a Macie finding, the content changed, or the owner asks.
2. The owner agrees the new level.
3. The object is moved to the right prefix and re-tagged.
4. Access logs are checked for who read it while it had the wrong label.
5. It goes in the risk register.

This happened in our lab. `internal/notes-export.csv` was labelled Internal, but it had card numbers pasted into support notes. Macie found it, and [scripts/remediate-misclassified.sh](../scripts/remediate-misclassified.sh) does steps 3 and 4. Write-up in the [Macie report](../week-4-compliance/macie-report.md).
