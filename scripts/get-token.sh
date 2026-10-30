#!/usr/bin/env bash
# Prints a fresh Cognito ID token for the test user (valid ~60 minutes).
#   export TOKEN=$(./scripts/get-token.sh)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
require aws jq
load_config
load_outputs
[[ -f "$TEST_USER_FILE" ]] || die "No test user yet. Run scripts/post-deploy.sh"

aws cognito-idp initiate-auth --auth-flow USER_PASSWORD_AUTH --client-id "$USER_POOL_CLIENT_ID" \
  --auth-parameters "USERNAME=$(jq -r .username "$TEST_USER_FILE"),PASSWORD=$(jq -r .password "$TEST_USER_FILE")" \
  --query AuthenticationResult.IdToken --output text
