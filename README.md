# ⏰ eventbridge-lambda-scheduler

A tiny AWS project that schedules a **Lambda** function with **Amazon EventBridge** (default: every 1 minute).

![Build](https://img.shields.io/badge/AWS-Lambda%20%2B%20EventBridge-orange)
![Python](https://img.shields.io/badge/Python-3.12-blue)

## 🚀 What it does

- Creates/updates a Lambda function (`python3.12`)
- Creates/updates an EventBridge **rate** rule to invoke the function periodically
- Grants EventBridge permission to call Lambda
- One-command cleanup

## 🧰 Prereqs

- AWS CLI configured (`aws configure`)
- Permissions to manage IAM/Lambda/EventBridge
- Python + pip (for optional packaging of dependencies)
- Bash

## 📦 Deploy

```bash
# Clone
git clone https://github.com/atulkamble/eventbridge-lambda-scheduler.git
cd eventbridge-lambda-scheduler

# Make scripts executable
chmod +x setup/*.sh

# (Optional) use a named AWS CLI profile and region
export PROFILE=my-aws-profile
export REGION=ap-south-1   # default is us-east-1

# Create/Update Lambda
./setup/create_lambda.sh

# Create/Update EventBridge Rule (default: rate(1 minute))
./setup/create_eventbridge_rule.sh

aws events describe-rule --name ScheduledLambdaRule --region us-east-1
aws events list-targets-by-rule --rule ScheduledLambdaRule --region us-east-1

aws lambda invoke \
  --function-name ScheduledLambdaFunction \
  --payload '{}' \
  --region us-east-1 \
  /dev/stdout


aws logs tail /aws/lambda/ScheduledLambdaFunction --since 15m --follow --region us-east-1

```

---

## 📁 Project Layout

```
eventbridge-lambda-scheduler/
│
├── .gitignore
├── README.md
│
├── lambda/
│   ├── lambda_function.py
│   └── requirements.txt
│
└── setup/
    ├── create_eventbridge_rule.sh
    ├── create_lambda.sh
    ├── cleanup.sh
    └── trust-policy.json
```

---

## 🔧 Files

### `.gitignore`

```gitignore
# Python
__pycache__/
*.pyc

# Packaging
function.zip
package/
dist/
build/

# OS/Editor
.DS_Store
.env
```

### `lambda/lambda_function.py`

```python
import json
from datetime import datetime, timezone

def lambda_handler(event, context):
    current_time = datetime.now(timezone.utc).isoformat()
    print(f"[INFO] Lambda triggered at (UTC): {current_time}")
    print(f"[INFO] Incoming event: {json.dumps(event)}")
    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Lambda executed successfully!", "time_utc": current_time})
    }
```

### `lambda/requirements.txt`

```
# Keep empty unless you add dependencies.
# Example:
# requests==2.32.3
```

### `setup/trust-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLambdaServiceToAssumeRole",
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### `setup/create_lambda.sh`

```bash
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
```

### `setup/create_eventbridge_rule.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# ---- Config (override via env) ----
RULE_NAME="${RULE_NAME:-ScheduledLambdaRule}"
FUNCTION_NAME="${FUNCTION_NAME:-ScheduledLambdaFunction}"
REGION="${REGION:-us-east-1}"
PROFILE_ARG="${PROFILE:+--profile $PROFILE}"
SCHEDULE_EXPRESSION="${SCHEDULE_EXPRESSION:-rate(1 minute)}"
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
```

### `setup/cleanup.sh`

```bash
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

echo "[SUCCESS] Cleanup complete."
```

### `README.md`

````markdown
# ⏰ eventbridge-lambda-scheduler

A tiny AWS project that schedules a **Lambda** function with **Amazon EventBridge** (default: every 1 minute).

![Build](https://img.shields.io/badge/AWS-Lambda%20%2B%20EventBridge-orange)
![Python](https://img.shields.io/badge/Python-3.12-blue)

## 🚀 What it does

- Creates/updates a Lambda function (`python3.12`)
- Creates/updates an EventBridge **rate** rule to invoke the function periodically
- Grants EventBridge permission to call Lambda
- One-command cleanup

## 🧰 Prereqs

- AWS CLI configured (`aws configure`)
- Permissions to manage IAM/Lambda/EventBridge
- Python + pip (for optional packaging of dependencies)
- Bash

## 📦 Deploy

```bash
# Clone
git clone https://github.com/<your-username>/eventbridge-lambda-scheduler.git
cd eventbridge-lambda-scheduler

# Make scripts executable
chmod +x setup/*.sh

# (Optional) use a named AWS CLI profile and region
export PROFILE=my-aws-profile
export REGION=ap-south-1   # default is us-east-1

# Create/Update Lambda
./setup/create_lambda.sh

# Create/Update EventBridge Rule (default: rate(1 minute))
./setup/create_eventbridge_rule.sh
````

### 🔁 Change the schedule

Use `SCHEDULE_EXPRESSION`:

```bash
SCHEDULE_EXPRESSION="rate(1 minute)" ./setup/create_eventbridge_rule.sh
# or a cron expression (UTC)
SCHEDULE_EXPRESSION="cron(0/5 * * * ? *)" ./setup/create_eventbridge_rule.sh
```

> **Note**: EventBridge cron is **UTC**. `rate()` uses minute/hour/day units.

## ✅ Validate

```bash
# Who am I?
aws sts get-caller-identity ${PROFILE:+--profile $PROFILE}

# Describe Lambda
aws lambda get-function --function-name ScheduledLambdaFunction --region ${REGION:-us-east-1} ${PROFILE:+--profile $PROFILE}

# Describe Rule / Targets
aws events describe-rule --name ScheduledLambdaRule --region ${REGION:-us-east-1} ${PROFILE:+--profile $PROFILE}
aws events list-targets-by-rule --rule ScheduledLambdaRule --region ${REGION:-us-east-1} ${PROFILE:+--profile $PROFILE}
```

### 🔎 Logs

Open CloudWatch Logs → the log group for your function. Or tail via CLI:

```bash
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/ScheduledLambdaFunction ${PROFILE:+--profile $PROFILE}
# Then tail the latest stream (example)
aws logs tail /aws/lambda/ScheduledLambdaFunction --follow ${PROFILE:+--profile $PROFILE}
```

## 🧹 Cleanup

```bash
./setup/cleanup.sh
```

## ⚙️ Environment overrides

These can be set before running scripts:

* `PROFILE` (AWS CLI profile)
* `REGION` (default `us-east-1`)
* `FUNCTION_NAME` (default `ScheduledLambdaFunction`)
* `RULE_NAME` (default `ScheduledLambdaRule`)
* `ROLE_NAME` (default `lambda-eventbridge-role`)
* `SCHEDULE_EXPRESSION` (default `rate(1 minute)`)

## 📦 Adding dependencies

Add packages to `lambda/requirements.txt` and re-run `setup/create_lambda.sh`. The script will vendor them into the deployment package automatically.

---

Made for quick demos, workshops, and training.

````

---

## ▶️ Quick Start 

```bash
sudo yum install -y git tree
git clone https://github.com/<your-username>/eventbridge-lambda-scheduler.git
cd eventbridge-lambda-scheduler
tree

chmod +x setup/*.sh
export REGION=ap-south-1   # optional
export PROFILE=default     # optional

./setup/create_lambda.sh
./setup/create_eventbridge_rule.sh
````

---

