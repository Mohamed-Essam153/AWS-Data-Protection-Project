"""dp-lab-api-fn

GET /customer behind API Gateway + Cognito.

Reads one customer from DynamoDB, lists a few files under internal/ in the data
bucket, and loads a secret and a SecureString parameter to prove the function can
reach them. It only returns the customer id and tier - no names, emails or other
personal data - and it never logs secret values.
"""
import json
import os

import boto3

_s3 = boto3.client("s3")
_secrets = boto3.client("secretsmanager")
_ssm = boto3.client("ssm")
_table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

# Simple warm-start cache so we don't call Secrets Manager / SSM on every request.
# A rotated secret is picked up when Lambda starts a new execution environment.
_cache = {}


def _secret_loaded():
    if "secret" not in _cache:
        resp = _secrets.get_secret_value(SecretId=os.environ["SECRET_ID"])
        _cache["secret"] = "SecretString" in resp
    return _cache["secret"]


def _config_loaded():
    if "config" not in _cache:
        resp = _ssm.get_parameter(Name=os.environ["PARAM_NAME"], WithDecryption=True)
        _cache["config"] = bool(resp["Parameter"]["Value"])
    return _cache["config"]


def _response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json", "Cache-Control": "no-store"},
        "body": json.dumps(body),
    }


def lambda_handler(event, context):
    params = (event or {}).get("queryStringParameters") or {}
    customer_id = params.get("id", "C-0001")
    if not (customer_id.startswith("C-") and customer_id[2:].isdigit() and len(customer_id) <= 10):
        return _response(400, {"error": "id must look like C-0001"})

    item = _table.get_item(Key={"customerId": customer_id}).get("Item")
    if not item:
        return _response(404, {"error": "customer not found"})

    listing = _s3.list_objects_v2(Bucket=os.environ["BUCKET_NAME"], Prefix="internal/", MaxKeys=5)
    files = [obj["Key"] for obj in listing.get("Contents", [])]

    body = {
        "customer": {"customerId": item["customerId"], "tier": item.get("tier")},
        "internalFiles": files,
        "secretLoaded": _secret_loaded(),
        "configLoaded": _config_loaded(),
    }
    print(json.dumps({"msg": "request ok", "customer": customer_id}))
    return _response(200, body)
