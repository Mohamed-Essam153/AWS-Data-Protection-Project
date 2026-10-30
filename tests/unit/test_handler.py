"""Unit tests for app/handler.py using moto (no AWS account needed).

    pip install -r tests/requirements.txt
    python -m pytest tests/unit -q
"""
import importlib
import json
import os
import sys

import boto3
import pytest
from moto import mock_aws

APP_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "app")
sys.path.insert(0, os.path.abspath(APP_DIR))

REGION = "us-east-1"
BUCKET = "dp-lab-data-test"
TABLE = "dp-lab-customers"
SECRET = "dp-lab/thirdparty/api-key"
PARAM = "/dp-lab/app/partner-endpoint"


@pytest.fixture
def handler(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", REGION)
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("TABLE_NAME", TABLE)
    monkeypatch.setenv("BUCKET_NAME", BUCKET)
    monkeypatch.setenv("SECRET_ID", SECRET)
    monkeypatch.setenv("PARAM_NAME", PARAM)

    with mock_aws():
        ddb = boto3.client("dynamodb", region_name=REGION)
        ddb.create_table(
            TableName=TABLE,
            AttributeDefinitions=[{"AttributeName": "customerId", "AttributeType": "S"}],
            KeySchema=[{"AttributeName": "customerId", "KeyType": "HASH"}],
            BillingMode="PAY_PER_REQUEST",
        )
        ddb.put_item(
            TableName=TABLE,
            Item={
                "customerId": {"S": "C-0001"},
                "tier": {"S": "gold"},
                "email": {"S": "someone@example.com"},
            },
        )
        s3 = boto3.client("s3", region_name=REGION)
        s3.create_bucket(Bucket=BUCKET)
        s3.put_object(Bucket=BUCKET, Key="internal/staff-directory.csv", Body=b"x")
        s3.put_object(Bucket=BUCKET, Key="restricted/payments.csv", Body=b"x")
        boto3.client("secretsmanager", region_name=REGION).create_secret(
            Name=SECRET, SecretString='{"api_key": "fake"}'
        )
        boto3.client("ssm", region_name=REGION).put_parameter(
            Name=PARAM, Type="SecureString", Value="https://partner.example.com/v1"
        )

        import handler as module

        importlib.reload(module)
        yield module


def call(module, params=None):
    resp = module.lambda_handler({"queryStringParameters": params}, None)
    return resp["statusCode"], json.loads(resp["body"])


def test_returns_customer_without_personal_data(handler):
    status, body = call(handler)
    assert status == 200
    assert body["customer"] == {"customerId": "C-0001", "tier": "gold"}
    assert "email" not in json.dumps(body)


def test_lists_only_internal_prefix(handler):
    _, body = call(handler)
    assert body["internalFiles"] == ["internal/staff-directory.csv"]


def test_secret_and_config_are_loaded_but_not_returned(handler):
    _, body = call(handler)
    assert body["secretLoaded"] is True
    assert body["configLoaded"] is True
    assert "fake" not in json.dumps(body)
    assert "partner.example.com" not in json.dumps(body)


def test_rejects_bad_id(handler):
    status, _ = call(handler, {"id": "<script>"})
    assert status == 400


def test_unknown_customer(handler):
    status, _ = call(handler, {"id": "C-9999"})
    assert status == 404
