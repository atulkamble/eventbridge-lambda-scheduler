#!/bin/bash
RULE_NAME="ScheduledLambdaRule"
FUNCTION_NAME="ScheduledLambdaFunction"
REGION="us-east-1"
SCHEDULE="rate(5 minutes)"

aws events put-rule --name $RULE_NAME --schedule-expression "$SCHEDULE"

LAMBDA_ARN=$(aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.FunctionArn' --output text)

aws lambda add-permission \
  --function-name $FUNCTION_NAME \
  --statement-id EventBridgeInvoke \
  --action 'lambda:InvokeFunction' \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:$REGION:$(aws sts get-caller-identity --query Account --output text):rule/$RULE_NAME

aws events put-targets --rule $RULE_NAME --targets "Id"="1","Arn"="$LAMBDA_ARN"
