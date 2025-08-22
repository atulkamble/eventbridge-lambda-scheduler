#!/usr/bin/env bash
set -euo pipefail

FUNCTION_NAME="${FUNCTION_NAME:-ScheduledLambdaFunction}"
ROLE_NAME="${ROLE_NAME:-lambda-eventbridge-role}"
RULE_NAME="${RULE_NAME:-ScheduledLambdaRule}"
REGION="${REGION:-us-east-1}"
PROFILE_ARG="${PROFILE:+--profile $PROFILE}"
STATEMENT_ID="${STATEMENT_ID:-EventBridgeInvoke}"

echo "[INFO] Removing EventBridge target if present..."
aws events remove-targets --rule "$RULE_NAME" --ids "1" --region "$REGION" $PROFILE_ARG >/dev/null 2>&1 || true
aws events delete-rule --name "$RULE_NAME" --region "$REGION" $PROFILE_ARG >/dev/null 2>&1 || true

echo "[INFO] Deleting Lambda if present..."
aws lambda delete-function --function-name "$FUNCTION_NAME" --region "$REGION" $PROFILE_ARG >/dev/null 2>&1 || true

echo "[INFO] Detaching and deleting IAM role if present..."
aws iam detach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
  $PROFILE_ARG >/dev/null 2>&1 || true
aws iam delete-role --role-name "$ROLE_NAME" $PROFILE_ARG >/dev/null 2>&1 || true

rm -f "$(dirname "$0")/../function.zip" 2>/dev/null || true
rm -rf "$(dirname "$0")/../package" 2>/dev/null || true

# --- Delete HTTP API (if present) ---
API_NAME="${API_NAME:-ScheduledLambdaAPI}"
API_ID=$(aws apigatewayv2 get-apis --region "$REGION" ${PROFILE:+--profile $PROFILE} \
  --query "Items[?Name=='${API_NAME}'].ApiId | [0]" --output text 2>/dev/null || true)

if [[ -n "${API_ID}" && "${API_ID}" != "None" ]]; then
  echo "[INFO] Deleting HTTP API: $API_NAME (ID: $API_ID)"
  aws apigatewayv2 delete-api --api-id "$API_ID" --region "$REGION" ${PROFILE:+--profile $PROFILE} >/dev/null || true
fi

echo "[SUCCESS] Cleanup complete."
