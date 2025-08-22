#!/usr/bin/env bash
set -euo pipefail

API_NAME="${API_NAME:-ScheduledLambdaAPI}"
REGION="${REGION:-us-east-1}"
PROFILE_ARG="${PROFILE:+--profile $PROFILE}"

# Find API by name
API_ID=$(aws apigatewayv2 get-apis --region "$REGION" $PROFILE_ARG \
  --query "Items[?Name=='${API_NAME}'].ApiId | [0]" --output text)

if [[ -z "${API_ID}" || "${API_ID}" == "None" ]]; then
  echo "[INFO] No HTTP API named '${API_NAME}' found. Nothing to delete."
  exit 0
fi

echo "[INFO] Deleting HTTP API: $API_NAME (ID: $API_ID)"
aws apigatewayv2 delete-api --api-id "$API_ID" --region "$REGION" $PROFILE_ARG >/dev/null

echo "[SUCCESS] API deleted."
