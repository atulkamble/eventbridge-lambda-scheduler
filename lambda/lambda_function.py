import json
from datetime import datetime, timezone

def lambda_handler(event, context):
    now = datetime.now(timezone.utc).isoformat()
    # Detect API Gateway (HTTP API) invocation
    is_http = isinstance(event, dict) and "requestContext" in event

    # Simple HTML page for browser
    html = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>EventBridge + Lambda</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    body {{ font-family: -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; margin: 2rem; }}
    .box {{ padding: 1rem 1.25rem; border: 1px solid #ccc; border-radius: 12px; }}
    code {{ background: #f6f8fa; padding: 0.2rem 0.4rem; border-radius: 6px; }}
  </style>
</head>
<body>
  <h1>✅ Lambda is running</h1>
  <div class="box">
    <p><strong>Triggered at (UTC):</strong> {now}</p>
    <p>Try <code>?format=json</code> to get JSON.</p>
  </div>
</body>
</html>"""

    # If invoked via API Gateway, serve HTML by default (or JSON if requested)
    if is_http:
        fmt = None
        qsp = event.get("queryStringParameters") or {}
        fmt = (qsp.get("format") or "").lower() if isinstance(qsp, dict) else None

        if fmt == "json":
            body = {"message": "Hello from Lambda (HTTP)!", "time_utc": now}
            return {
                "statusCode": 200,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*",
                },
                "body": json.dumps(body),
            }
        else:
            return {
                "statusCode": 200,
                "headers": {
                    "Content-Type": "text/html; charset=utf-8",
                    "Access-Control-Allow-Origin": "*",
                },
                "body": html,
            }

    # Otherwise (e.g., EventBridge schedule), keep JSON return
    print(f"[INFO] Lambda triggered at (UTC): {now}")
    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Lambda executed successfully!", "time_utc": now}),
    }
