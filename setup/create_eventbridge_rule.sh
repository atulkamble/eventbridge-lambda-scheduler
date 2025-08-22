#!/usr/bin/env bash
set -euo pipefail

# ---- Config (override via env) ----
RULE_NAME="${RULE_NAME:-ScheduledLambdaRule}"
FUNCTION_NAME="${FUNCTION_NAME:-ScheduledLambdaFunction}"
REGION="${REGION:-us-east-1}"
PROFILE_ARG="${PROFILE:+--profile $PROFILE}"
SCHEDULE_EXPRESSION="${SCHEDULE_EXPRESSION:-rate(1 Minute)}"
STATEMENT_ID="${STATEMENT_ID:-EventBridgeInvoke}"

echo "[INFO] Creating/Updating EventBridge rule '$RULE_NAME' with schedule: $SCHEDULE_EXPRESSION"

aws events put-rule \
  --name "$RULE_NAME" \
  --schedule-expression "$SCHEDULE_EXPRESSION" \
  --region "$REGION" \
  $PROFILE_ARG >/dev/null

LAMBDA_ARN=$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  $PROFILE_ARG --query 'Configuration.FunctionArn' --output text)

ACCOUNT_ID=$(aws sts get-caller-identity $PROFILE_ARG --query Account --output text)
RULE_ARN="arn:aws:events:${REGION}:${ACCOUNT_ID}:rule/${RULE_NAME}"

# Add permission (idempotent: ignore if exists)
echo "[INFO] Adding invoke permission for EventBridge → Lambda (may error if already exists)"
aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id "$STATEMENT_ID" \
  --action 'lambda:InvokeFunction' \
  --principal events.amazonaws.com \
  --source-arn "$RULE_ARN" \
  --region "$REGION" \
  $PROFILE_ARG >/dev/null 2>&1 || true

# Put target
echo "[INFO] Setting EventBridge target"
aws events put-targets \
  --rule "$RULE_NAME" \
  --targets "Id"="1","Arn"="$LAMBDA_ARN" \
  --region "$REGION" \
  $PROFILE_ARG >/dev/null

echo "[SUCCESS] Rule '$RULE_NAME' targets Lambda '$FUNCTION_NAME'"

