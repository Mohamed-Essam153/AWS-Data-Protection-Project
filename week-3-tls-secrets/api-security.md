# API security controls

Deliverable 15. Owner: Mohamed Essam Elbastawisy. Template: [04-app.yaml](../infra/04-app.yaml)

| Control | Stops | Setting | Test | Expected |
|---|---|---|---|---|
| Cognito authorizer | anonymous access | user pool with email sign-in, admin-created users only, 12+ char passwords; authorizer on `GET /customer` | T22, T23 | 401 without token, 200 with |
| Stage throttling | abuse, runaway cost | `prod`: 5 requests/s, burst 10 | T25 | some 429 out of 60 parallel |
| AWS WAF (optional) | XSS, SQLi, known bad inputs, floods | AWS Common Rule Set, Known Bad Inputs, rate limit 100 per IP per 5 min | T24 | 403 |
| TLS 1.2+ only | eavesdropping, downgrade | API security policy `SecurityPolicy_TLS13_1_2_2021_06` | T20, T21 | see [tls.md](tls.md) |
| Access logs | no trail to investigate | JSON access log per request (id, IP, status, user, WAF result); no bodies | console | entries in `/aws/apigateway/dp-lab-api` |
| Least-privilege Lambda | lateral movement | [demo-app.md](demo-app.md) | access review | - |
| Minimal responses | data leaking through the API | ID and tier only | T23 | no `@` in the body |
| Input check | junk reaching the backend | `id` must look like `C-0001` | unit test | 400 |

## Running the checks yourself

```bash
source ~/.dp-lab/outputs.env
export TOKEN=$(./scripts/get-token.sh)

curl -s -o /dev/null -w "%{http_code}\n" $API_URL                       # 401
curl -s -H "Authorization: $TOKEN" $API_URL                             # 200 + JSON

( for i in $(seq 1 60); do
    curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: $TOKEN" $API_URL &
  done; wait ) | sort | uniq -c                                         # some 429

curl -G -s -o /dev/null -w "%{http_code}\n" -H "Authorization: $TOKEN" \
  --data-urlencode "q=<script>alert(1)</script>" $API_URL               # 403 with WAF on
```

The test user's password is random and lives in `~/.dp-lab/test-user.json` in CloudShell. `get-token.sh` reads it so nobody has to type or paste it.

## Designed, not built

- **CORS**: only needed once there's a browser front end; then allow just that origin.
- **Request validation**: API Gateway request validators and models, to reject malformed requests before Lambda runs.
- **Usage plans and API keys** for partners: they identify a caller and enforce quotas, they don't authenticate.
- **Mutual TLS** on a custom domain for B2B partners.
- **Cognito MFA** for real users. Off for the scripted test user.
