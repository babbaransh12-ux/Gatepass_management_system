import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from twilio.rest import Client
from dotenv import load_dotenv

load_dotenv()

ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID")
AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN")
FROM_NUMBER = os.getenv("TWILIO_PHONE_NUMBER")

client = None
if ACCOUNT_SID and AUTH_TOKEN:
    client = Client(ACCOUNT_SID, AUTH_TOKEN)

def send_sms(to_phone, body):
    if not client:
        print("Warning: Twilio client not initialized. Cannot send SMS.")
        return False

    try:
        message = client.messages.create(
            body=body,
            from_=FROM_NUMBER,
            to=to_phone
        )
        print(f"SMS SENT to {to_phone}: {message.sid}")
        return True
    except Exception as e:
        print(f"SMS FAILED to {to_phone}: {e}")
        return False
