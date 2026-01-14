import json
import boto3
import os

SNS_TOPIC = os.environ.get('SNS_TOPIC')
SES_REGION = "eu-central-1"
SES_SOURCE = "546323@student.fontys.nl"
SES_DESTINATION = "546323@student.fontys.nl"

ses_client = boto3.client('ses', region_name=SES_REGION)

def handler(event, context):
    print("Received event: " , json.dumps(event, indent=2))

    for record in event.get("Records", []):
        message = record.get("Sns", {}).get("Message", "")

        try:
            alert = json.loads(message)
        except json.JSONDecodeError:
            
            try:
                fixed = (
                    message
                    .replace("{", '{"')
                    .replace("}", '"}')
                    .replace(", ", '", "')
                    .replace(": ", '": "')
                    .replace("'", '"')
                )
                alert = json.loads(fixed)
                print("[INFO] Fixed malformed JSON successfully.")
            except json.JSONDecodeError:
                print(f"[ERROR] Failed to parse message: {message}")
                continue

        subject = f"SOAR Alert: {alert.get('type', 'Unknown')}"
        body = f"Alert recieved from {alert.get('source', 'Unknown')}:\n\n{json.dumps(alert, indent=2)}"

        try:
            response = ses_client.send_email(
                Source=SES_SOURCE,
                Destination={"ToAddresses": [SES_DESTINATION]},
                Message={
                    "Subject": {"Data": subject},
                    "Body": {"Text": {"Data": body}}
                }
            )
            print(f"[INFO] Email sent successfully: {response['MessageId']}")
        except Exception as e:
            print(f"[ERROR] Failed to send email: {str(e)}")