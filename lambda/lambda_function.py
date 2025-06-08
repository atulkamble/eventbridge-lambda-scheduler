import json
import datetime

def lambda_handler(event, context):
    print(f"Lambda triggered at: {datetime.datetime.now().isoformat()}")
    return {
        'statusCode': 200,
        'body': json.dumps('Lambda executed successfully!')
    }
