#!/usr/bin/env bash
# Shared helpers. Sourced by the other scripts, not run directly.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$HOME/.dp-lab"
OUTPUTS_FILE="$STATE_DIR/outputs.env"
# shellcheck disable=SC2034  # used by the scripts that source this file
TEST_USER_FILE="$STATE_DIR/test-user.json"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

load_config() {
  local cfg="$REPO_ROOT/config.env"
  [[ -f "$cfg" ]] || die "config.env not found. Run: cp config.example.env config.env  and edit it."
  # shellcheck disable=SC1090
  source "$cfg"
  [[ "${SUFFIX:-changeme}" != "changeme" ]] || die "Set SUFFIX in config.env"
  [[ "$SUFFIX" =~ ^[a-z0-9]{4,8}$ ]] || die "SUFFIX must be 4-8 lowercase letters or digits"
  export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"
  mkdir -p "$STATE_DIR" && chmod 700 "$STATE_DIR"
}

load_outputs() {
  [[ -f "$OUTPUTS_FILE" ]] || die "No deployment outputs found. Run scripts/deploy.sh first."
  # shellcheck disable=SC1090
  source "$OUTPUTS_FILE"
}

require() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' is required but not installed"
  done
}

account_id() { aws sts get-caller-identity --query Account --output text; }

# Turns the current sign-in (SSO assumed role or IAM user) into an IAM ARN usable
# in a key policy. Refuses to run as root.
caller_principal_arn() {
  local arn role
  arn=$(aws sts get-caller-identity --query Arn --output text)
  case "$arn" in
    *:root) die "Don't run this as the root user. Sign in through IAM Identity Center." ;;
    arn:aws:iam::*:user/*) echo "$arn" ;;
    arn:aws:sts::*:assumed-role/*)
      role=$(echo "$arn" | cut -d/ -f2)
      aws iam get-role --role-name "$role" --query Role.Arn --output text ;;
    *) die "Can't work out an IAM principal from $arn" ;;
  esac
}

stack_output() {
  aws cloudformation describe-stacks --stack-name "$1" \
    --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue | [0]" --output text 2>/dev/null
}

deploy_stack() {
  local name=$1 template=$2; shift 2
  log "Deploying $name"
  local args=(--stack-name "$name" --template-file "$REPO_ROOT/infra/$template"
              --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset
              --tags "Owner=$OWNER" Environment=Lab Project=DataProtection)
  if (( $# > 0 )); then args+=(--parameter-overrides "$@"); fi
  aws cloudformation deploy "${args[@]}" \
    || die "Stack $name failed. Check the Events tab of the stack in the CloudFormation console."
}

redact() { sed -E 's/[0-9]{12}/<ACCOUNT_ID>/g'; }
