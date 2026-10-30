# Access review

Deliverable 4. Owner: Ahmed Shaaban. Done twice: end of week 1 and end of week 3.

## Where we looked

- IAM Identity Center users, groups and permission sets
- IAM roles (anything starting `dp-lab-`)
- Data bucket policy and the access point policy
- KMS key policies
- IAM Access Analyzer (test T09)
- IAM credential report: `aws iam generate-credential-report` then `aws iam get-credential-report`

## Review 1 - end of week 1

| Principal | Can reach | Level | Why | Decision |
|---|---|---|---|---|
| Group `DPLabTeam` (`DPLabAdmin`) | whole account | admin | building the lab | keep for the lab only (risk R-05) |
| `dp-lab-analytics-role` | access point, `internal/*` | read | least-privilege test | keep |
| Account root via `DelegateToAccountAccessPoints` | data bucket, only through our access points | delegated | needed for access points to work | keep |
| Root user | account | full | emergencies; MFA on, no keys | keep, unused |
| IAM users | - | - | there shouldn't be any | check credential report |

## Review 2 - end of week 3

| Principal | Can reach | Level | Why | Decision |
|---|---|---|---|---|
| `dp-lab-api-fn-role` | one DynamoDB table (GetItem), list `internal/`, one secret, `/dp-lab/app/*` params, decrypt via those services only | read, scoped | demo API | keep |
| Macie service-linked role | decrypt with the S3 key | decrypt | sensitive data discovery | keep while Macie is on |
| `dp-lab-apigw-cloudwatch` | CloudWatch Logs | write | API access logs | keep |
| Cognito user `dp-lab-tester@example.com` | `GET /customer` | invoke | tests and demo | delete at teardown (goes with the user pool) |

## Notes

The review is a table someone signs off, not a tool. Each row should end in keep, reduce, or remove, with a name and date beside it. Fill in reviewer and date when you do it:

| Review | Reviewer | Date |
|---|---|---|
| 1 | | |
| 2 | | |
