#!/bin/bash
FUNCTION_NAME="ScheduledLambdaFunction"
ROLE_NAME="lambda-eventbridge-role"
ZIP_FILE="function.zip"
REGION="us-east-1"

cd lambda && zip -r9 ../$ZIP_FILE . && cd ..

aws iam create-role --role-name $ROLE_NAME \
  --assume-role-policy-document file://setup/trust-policy.json

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

echo "Waiting for role propagation..."
sleep 10

aws lambda create-function \
  --function-name $FUNCTION_NAME \
  --runtime python3.12 \
  --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$ROLE_NAME \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://$ZIP_FILE \
  --region $REGION
