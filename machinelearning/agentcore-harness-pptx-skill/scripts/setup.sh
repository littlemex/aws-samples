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
SKILLS=$(cat <<JSON
[
  {"git": {"url": "$PUBLISHED_SKILL_URL", "path": "$PUBLISHED_SKILL_PATH"}},
  {"s3": {"uri": "s3://$SKILL_BUCKET/skills/corporate-deck/"}}
]
JSON
)
PROMPT='[{"text": "You produce presentation decks. Always use the corporate-deck skill for layout and the published pptx skill for anything it does not cover. Never hand over a deck that has not passed check_deck.py."}]'

if HARNESS=$(aws bedrock-agentcore-control list-harnesses \
      --query "harnesses[?harnessName=='$HARNESS_NAME']|[0].harnessId" \
      --output text 2>/dev/null) && [ "$HARNESS" != "None" ] && [ -n "$HARNESS" ]; then
  aws bedrock-agentcore-control update-harness \
    --harness-id "$HARNESS" --skills "$SKILLS" --system-prompt "$PROMPT" >/dev/null
else
  aws bedrock-agentcore-control create-harness \
    --harness-name "$HARNESS_NAME" \
    --execution-role-arn "$ROLE_ARN" \
    --skills "$SKILLS" \
    --system-prompt "$PROMPT" >/dev/null
  HARNESS=$(aws bedrock-agentcore-control list-harnesses \
    --query "harnesses[?harnessName=='$HARNESS_NAME']|[0].harnessId" --output text)
fi

echo
echo "export HARNESS_ID=$HARNESS"
echo
echo "Poll until the status is READY:"
echo "  aws bedrock-agentcore-control get-harness --harness-id \$HARNESS_ID"
echo "Then resolve the ARN and ask for a deck:"
echo "  export HARNESS_ARN=\$(aws bedrock-agentcore-control get-harness \\"
echo "    --harness-id \"\$HARNESS_ID\" --query 'harnessArn || arn' --output text)"
echo "  python3 scripts/invoke.py 'Build a five slide deck on ...'"
