#!/usr/bin/env bash
set -euo pipefail

# ---- Config (override via env or CLI) ----
FUNCTION_NAME="${FUNCTION_NAME:-ScheduledLambdaFunction}"
ROLE_NAME="${ROLE_NAME:-lambda-eventbridge-role}"
REGION="${REGION:-us-east-1}"
PROFILE_ARG="${PROFILE:+--profile $PROFILE}"   # export PROFILE=myprofile to use a named profile
RUNTIME="${RUNTIME:-python3.12}"
HANDLER="${HANDLER:-lambda_function.lambda_handler}"
ZIP_FILE="function.zip"

echo "[INFO] Using region: $REGION ${PROFILE:+(profile: $PROFILE)}"

# ---- Package Lambda code (supports requirements.txt if not empty) ----
pushd "$(dirname "$0")/../lambda" >/dev/null

rm -f "../$ZIP_FILE"
rm -rf package
mkdir -p package

if [ -s requirements.txt ]; then
  echo "[INFO] Installing dependencies into package/ ..."
  pip install --upgrade pip >/dev/null
  pip install -r requirements.txt -t package >/dev/null
fi

echo "[INFO] Zipping source..."
pushd package >/dev/null
zip -qr "../../$ZIP_FILE" .
popd >/dev/null

zip -gq "../$ZIP_FILE" lambda_function.py
popd >/dev/null

# ---- Create (or reuse) IAM Role ----
ACCOUNT_ID=$(aws sts get-caller-identity $PROFILE_ARG --query Account --output text)
ROLE_EXISTS=$(aws iam get-role --role-name "$ROLE_NAME" $PROFILE_ARG >/dev/null 2>&1 && echo "yes" || echo "no")

if [ "$ROLE_EXISTS" = "no" ]; then
  echo "[INFO] Creating IAM role: $ROLE_NAME"
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file://$(dirname "$0")/trust-policy.json \
    $PROFILE_ARG >/dev/null

  aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
    $PROFILE_ARG >/dev/null
else
  echo "[INFO] IAM role already exists: $ROLE_NAME"
fi

# Wait briefly for role propagation
echo "[INFO] Waiting for role to propagate..."
sleep 10

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# ---- Create or Update Lambda ----
FUNC_EXISTS=$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" $PROFILE_ARG >/dev/null 2>&1 && echo "yes" || echo "no")

if [ "$FUNC_EXISTS" = "no" ]; then
  echo "[INFO] Creating Lambda function: $FUNCTION_NAME"
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime "$RUNTIME" \
    --role "$ROLE_ARN" \
    --handler "$HANDLER" \
    --zip-file "fileb://$ZIP_FILE" \
    --region "$REGION" \
    $PROFILE_ARG >/dev/null
else
  echo "[INFO] Updating Lambda code for: $FUNCTION_NAME"
  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://$ZIP_FILE" \
    --region "$REGION" \
    $PROFILE_ARG >/dev/null
fi

echo "[SUCCESS] Lambda ready: $FUNCTION_NAME"
