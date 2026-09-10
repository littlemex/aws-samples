#!/usr/bin/env bash
#
# Create the execution role, the skill bucket, and the harness.
# Reads its configuration from the environment; see the repository README.
set -euo pipefail

: "${AWS_REGION:?set AWS_REGION to a region where AgentCore harness is available}"
: "${SKILL_BUCKET:?set SKILL_BUCKET to the bucket that will hold the corporate skill}"

HARNESS_NAME="${HARNESS_NAME:-CorporateDeckHarness}"
ROLE_NAME="${ROLE_NAME:-${HARNESS_NAME}Role}"
PUBLISHED_SKILL_URL="${PUBLISHED_SKILL_URL:-https://github.com/anthropics/skills}"
PUBLISHED_SKILL_PATH="${PUBLISHED_SKILL_PATH:-skills/pptx}"
ARTIFACT_BUCKET="${ARTIFACT_BUCKET:-$SKILL_BUCKET}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

render() {
  sed -e "s|\${ACCOUNT_ID}|$ACCOUNT_ID|g" \
      -e "s|\${AWS_REGION}|$AWS_REGION|g" \
      -e "s|\${SKILL_BUCKET}|$SKILL_BUCKET|g" \
      -e "s|\${ARTIFACT_BUCKET}|$ARTIFACT_BUCKET|g" "$1"
}

echo "[1/4] execution role $ROLE_NAME"
render "$ROOT/iam/trust-policy.json" > "$WORK/trust.json"
render "$ROOT/iam/execution-role-policy.json" > "$WORK/policy.json"
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam create-role --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://$WORK/trust.json" >/dev/null
fi
aws iam put-role-policy --role-name "$ROLE_NAME" \
  --policy-name "${HARNESS_NAME}Inline" \
  --policy-document "file://$WORK/policy.json"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

echo "[2/4] skill bucket s3://$SKILL_BUCKET"
if ! aws s3api head-bucket --bucket "$SKILL_BUCKET" >/dev/null 2>&1; then
  if [ "$AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$SKILL_BUCKET" >/dev/null
  else
    aws s3api create-bucket --bucket "$SKILL_BUCKET" \
      --create-bucket-configuration "LocationConstraint=$AWS_REGION" >/dev/null
  fi
fi

echo "[3/4] upload the corporate skill"
aws s3 sync "$ROOT/skills/corporate-deck/" \
  "s3://$SKILL_BUCKET/skills/corporate-deck/" --delete

echo "[4/4] harness $HARNESS_NAME"
# Driven through boto3: the harness API is recent enough that an AWS CLI
# installed a few months ago has no create-harness subcommand.
"${PYTHON:-python3}" "$HERE/harness.py" \
  --name "$HARNESS_NAME" \
  --execution-role-arn "$ROLE_ARN" \
  --skill-uri "s3://$SKILL_BUCKET/skills/corporate-deck/" \
  --published-url "$PUBLISHED_SKILL_URL" \
  --published-path "$PUBLISHED_SKILL_PATH" \
  --region "$AWS_REGION" | tee "$ROOT/.harness.env"

echo
echo "Load the harness identifiers, then ask for a deck:"
echo "  source .harness.env"
echo "  python3 scripts/invoke.py 'Build a five slide deck on ...'"
