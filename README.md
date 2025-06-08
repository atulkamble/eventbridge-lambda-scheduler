Here’s a simple **AWS EventBridge + Lambda** integration project setup that you can push to GitHub. This project demonstrates triggering a Lambda function on a scheduled EventBridge rule (e.g., every 5 minutes).

---

## ✅ **Project Title:** `eventbridge-lambda-scheduler`

### 🎯 **Objective:**

Create a scheduled AWS EventBridge rule to trigger a Lambda function at regular intervals.

---

## 📁 **Project Structure**

```
eventbridge-lambda-scheduler/
│
├── lambda/
│   ├── lambda_function.py
│   └── requirements.txt
│
├── setup/
│   ├── create_lambda.sh
│   ├── create_eventbridge_rule.sh
│   └── cleanup.sh
│
├── README.md
```

---

### 🐍 `lambda/lambda_function.py`

```python
import json
import datetime

def lambda_handler(event, context):
    current_time = datetime.datetime.now().isoformat()
    print(f"Lambda triggered at: {current_time}")
    return {
        'statusCode': 200,
        'body': json.dumps('Lambda executed successfully!')
    }
```

---

### 📦 `lambda/requirements.txt`

Leave it empty for now, unless you add dependencies later.

---

### ⚙️ `setup/create_lambda.sh`

```bash
#!/bin/bash

FUNCTION_NAME="ScheduledLambdaFunction"
ROLE_NAME="lambda-eventbridge-role"
ZIP_FILE="function.zip"
REGION="us-east-1"

cd lambda || exit
zip -r9 ../$ZIP_FILE .
cd ..

aws iam create-role --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

echo "Waiting for role to be fully propagated..."
sleep 10

aws lambda create-function \
  --function-name $FUNCTION_NAME \
  --runtime python3.12 \
  --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$ROLE_NAME \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://$ZIP_FILE \
  --region $REGION
```

---

### 📜 `setup/trust-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "lambda.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
```

---

### ⏰ `setup/create_eventbridge_rule.sh`

```bash
#!/bin/bash

RULE_NAME="ScheduledLambdaRule"
FUNCTION_NAME="ScheduledLambdaFunction"
REGION="us-east-1"
SCHEDULE_EXPRESSION="rate(5 minutes)"  # Modify as needed

aws events put-rule \
  --name $RULE_NAME \
  --schedule-expression "$SCHEDULE_EXPRESSION" \
  --region $REGION

LAMBDA_ARN=$(aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.FunctionArn' --output text)

aws lambda add-permission \
  --function-name $FUNCTION_NAME \
  --statement-id EventBridgeInvoke \
  --action 'lambda:InvokeFunction' \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:$REGION:$(aws sts get-caller-identity --query Account --output text):rule/$RULE_NAME

aws events put-targets \
  --rule $RULE_NAME \
  --targets "Id"="1","Arn"="$LAMBDA_ARN"
```

---

### 🧹 `setup/cleanup.sh`

```bash
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
```

---

### 📝 `README.md`

````markdown
# ⏰ AWS EventBridge + Lambda Scheduler

This project demonstrates how to create a Lambda function that is triggered on a schedule using Amazon EventBridge.

## ✅ Steps

1. Create Lambda function and IAM Role:
   ```bash
   bash setup/create_lambda.sh
````

2. Create EventBridge Rule:

   ```bash
   bash setup/create_eventbridge_rule.sh
   ```

3. To clean up resources:

   ```bash
   bash setup/cleanup.sh
   ```

## 🧰 Tech Stack

* AWS Lambda (Python 3.12)
* Amazon EventBridge (Scheduled Rule)
* AWS CLI

```

---

Would you like me to create a GitHub README badge set and `.gitignore` as well?
```
