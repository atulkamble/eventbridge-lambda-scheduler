#!/bin/bash
FUNCTION_NAME="ScheduledLambdaFunction"
ROLE_NAME="lambda-eventbridge-role"
RULE_NAME="ScheduledLambdaRule"
REGION="us-east-1"

aws events remove-targets --rule $RULE_NAME --ids "1"
aws events delete-rule --name $RULE_NAME
aws lambda delete-function --function-name $FUNCTION_NAME
aws iam detach-role-policy --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name $ROLE_NAME

rm -f function.zip
