# TLS setup

Deliverable 12. Owner: Mohamed Essam Elbastawisy

## What we did

We don't own a domain, so the API is reached on its default `execute-api` hostname. API Gateway serves that with an AWS-managed certificate, HTTPS only.

The part people usually miss: a Regional REST API defaults to the `TLS_1_0` security policy, which still accepts TLS 1.0 and 1.1. We set the API's own security policy to `SecurityPolicy_TLS13_1_2_2021_06`, which accepts TLS 1.3 and 1.2 only ([list of policies](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-security-policies-list.html)). This newer type of policy also needs an endpoint access mode; we use `BASIC`. `STRICT` adds host/SNI checks but takes about 15 minutes to take effect ([AWS docs](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-security-policies.html)), so it's a parameter you can switch to after the demo setup is stable.

```yaml
Api:
  Type: AWS::ApiGateway::RestApi
  Properties:
    EndpointConfiguration: { Types: [REGIONAL] }
    SecurityPolicy: SecurityPolicy_TLS13_1_2_2021_06
    EndpointAccessMode: !Ref EndpointAccessMode
```

## Tests

T20 and T21 in the test report:

```bash
aws apigateway get-rest-api --rest-api-id $API_ID --query '[securityPolicy,endpointAccessMode]'
curl -sv -o /dev/null $API_URL 2>&1 | grep -E "SSL connection using|issuer:|expire date:"
curl --tlsv1.0 --tls-max 1.1 $API_URL          # fails
curl -m 8 http://<api-host>/prod/customer      # nothing listens on port 80
```

| Check | Expected |
|---|---|
| Security policy | `SecurityPolicy_TLS13_1_2_2021_06` |
| Negotiated | TLSv1.3 (or 1.2) |
| Issuer | Amazon |
| TLS 1.0/1.1 | handshake fails |
| HTTP | no response |

## With a domain (ACM)

If the team gets a domain, this is the upgrade path:

1. **ACM > Request public certificate** for `api.<domain>`, DNS validation, same region as the API. Add the CNAME it gives you and wait for *Issued*.
2. **API Gateway > Custom domain names > Create**: Regional, the same TLS 1.2+ security policy, pick the certificate.
3. **API mappings**: `dp-lab-api`, stage `prod`. Point `api.<domain>` at the API Gateway domain name.
4. Disable the default `execute-api` endpoint so all traffic uses the custom domain.

ACM renews DNS-validated public certificates by itself as long as the CNAME stays in place. The `dp-lab-acm-expiry` rule emails us if a certificate gets close to expiry anyway (see [certificate-inventory.md](certificate-inventory.md)).
