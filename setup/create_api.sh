#!/usr/bin/env bash
set -euo pipefail

API_NAME="${API_NAME:-ScheduledLambdaAPI}"
FUNCTION_NAME="${FUNCTION_NAME:-ScheduledLambdaFunction}"
REGION="${REGION:-us-east-1}"
PROFILE_ARG="${PROFILE:+--profile $PROFILE}"

echo "[INFO] Creating/Updating HTTP API for Lambda: $FUNCTION_NAME"

# Get Lambda ARN
LAMBDA_ARN=$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" $PROFILE_ARG \
  --query 'Configuration.FunctionArn' --output text)

# Create HTTP API with default route -> Lambda target (this creates integration + $default route)
CREATE_OUT=$(aws apigatewayv2 create-api \
  --name "$API_NAME" \
  --protocol-type HTTP \
  --target "$LAMBDA_ARN" \
  --cors-configuration 'AllowOrigins=["*"],AllowMethods=["GET","OPTIONS"]' \
  --region "$REGION" \
  $PROFILE_ARG)

API_ID=$(echo "$CREATE_OUT" | jq -r '.ApiId')
API_ENDPOINT=$(echo "$CREATE_OUT" | jq -r '.ApiEndpoint')

echo "[INFO] API created: ID=$API_ID  Endpoint=$API_ENDPOINT"

# Allow API Gateway to invoke Lambda
ACCOUNT_ID=$(aws sts get-caller-identity $PROFILE_ARG --query Account --output text)
SOURCE_ARN="arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*/*"

# Idempotent permission add
aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id "ApiGatewayInvoke" \
  --action "lambda:InvokeFunction" \
  --principal apigateway.amazonaws.com \
  --source-arn "$SOURCE_ARN" \
  --region "$REGION" \
  $PROFILE_ARG >/dev/null 2>&1 || true

echo "[SUCCESS] Open in browser:"
echo "  ${API_ENDPOINT}"
echo
echo "[TIP] JSON output:"
echo "  ${API_ENDPOINT}?format=json"
