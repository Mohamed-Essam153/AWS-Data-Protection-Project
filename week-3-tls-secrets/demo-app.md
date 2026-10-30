# Demo application

Owner: Mohamed Essam Elbastawisy. Template: [04-app.yaml](../infra/04-app.yaml). Code: [app/handler.py](../app/handler.py)

![Data in transit](../architecture/data-in-transit.png)

```
curl ──HTTPS (TLS 1.2+)──> [WAF, optional] ──> API Gateway REST  ──> Lambda dp-lab-api-fn
                                                Cognito authorizer        ├─ DynamoDB  dp-lab-customers   (GetItem)
                                                throttling 5 rps / 10     ├─ S3        internal/ listing   (ListBucket)
                                                access logs               ├─ Secrets Manager  api key      (GetSecretValue)
                                                                          └─ SSM  partner endpoint         (GetParameter, decrypted)
```

`GET /customer?id=C-0001` returns:

```json
{"customer": {"customerId": "C-0001", "tier": "gold"},
 "internalFiles": ["internal/notes-export.csv", "internal/staff-directory.csv"],
 "secretLoaded": true, "configLoaded": true}
```

The DynamoDB item also has a (fake) name and email. The function deliberately leaves them out: the API returns the minimum, and the logs only get `request ok` plus the customer ID. Secrets are loaded to prove the function can reach them, never returned or printed.

The `id` parameter is checked (`C-` followed by digits) before anything is looked up; anything else gets a 400.

## The function's permissions

Role `dp-lab-api-fn-role`, nothing else attached:

| Allows | On | Limited by |
|---|---|---|
| `logs:CreateLogStream`, `PutLogEvents` | its own log group | - |
| `dynamodb:GetItem` | `dp-lab-customers` | - |
| `s3:ListBucket` | data bucket | `s3:prefix` = `internal/*` |
| `secretsmanager:GetSecretValue` | the one secret | - |
| `ssm:GetParameter` | `/dp-lab/app/*` | - |
| `kms:Decrypt` | `dp-lab-secrets` | only via Secrets Manager or SSM |
| `kms:Decrypt` | `dp-lab-db` | only via DynamoDB |

## Unit tests

[tests/unit/test_handler.py](../tests/unit/test_handler.py) runs the handler against moto: customer returned without email, only `internal/` listed, secret and config loaded but not echoed, bad ID rejected, unknown ID 404.

```bash
pip install -r tests/requirements.txt
python -m pytest tests/unit -q
```
