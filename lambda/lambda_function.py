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
