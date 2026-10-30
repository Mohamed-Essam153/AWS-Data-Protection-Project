# Certificate inventory

Deliverable 13. Owner: Mohamed Essam Elbastawisy

| Endpoint | Certificate | Issuer | Renewal | Used by | Owner |
|---|---|---|---|---|---|
| `<api-id>.execute-api.us-east-1.amazonaws.com` | AWS-managed | Amazon | AWS | API Gateway | AWS (shared responsibility); policy choice is ours |
| `api.<domain>` (only if we add a domain) | ACM public, DNS validated | Amazon | ACM automatic | API Gateway custom domain | Mohamed |
| `dp-lab-db` endpoint (if RDS is on) | RDS CA | Amazon RDS | rotate CA when AWS announces | PostgreSQL clients | Ammar |
| S3, KMS, DynamoDB, Secrets Manager, SSM endpoints | AWS-managed | Amazon | AWS | SDK calls from Lambda and CloudShell | AWS |

Fill in the expiry dates from your own run:

```bash
# API certificate subject, issuer and expiry
curl -sv -o /dev/null $API_URL 2>&1 | grep -E "subject:|issuer:|expire date:"
# ACM certificates in the account (empty unless we added a domain)
aws acm list-certificates --query 'CertificateSummaryList[].[DomainName,Status,NotAfter]'
# RDS CA in use
aws rds describe-db-instances --db-instance-identifier dp-lab-db --query 'DBInstances[0].CACertificateIdentifier'
```

| Endpoint | Expires (from our run) | Checked on |
|---|---|---|
| API | | |
| RDS CA | | |

## Expiry alerting

EventBridge rule `dp-lab-acm-expiry` in [04-app.yaml](../infra/04-app.yaml) sends ACM's "Certificate Approaching Expiration" events to the `dp-lab-security-alerts` topic. ACM starts sending those 45 days before expiry.
