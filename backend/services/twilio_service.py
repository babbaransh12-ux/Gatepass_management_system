import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from twilio.rest import Client
from dotenv import load_dotenv
from datetime import datetime
from db import get_db

load_dotenv()

ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID")
AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN")
FROM_NUMBER = os.getenv("TWILIO_PHONE_NUMBER")
BASE_URL = os.getenv("BASE_URL")

# Make sure we don't crash if environment variables are not properly set, so only instantiate Client if credentials exist
client = None
if ACCOUNT_SID and AUTH_TOKEN:
    client = Client(ACCOUNT_SID, AUTH_TOKEN)

def format_number(phone):
    """Ensure phone number is in E.164 format for Twilio."""
    if not phone: return None
    phone_str = str(phone).strip()
    
    # If it's 10 digits and doesn't start with +, prepend +91 (India default)
    if len(phone_str) == 10 and not phone_str.startswith('+'):
        return f"+91{phone_str}"
    
    # If it's missing the +, but has country code, prepend +
    if not phone_str.startswith('+'):
        return f"+{phone_str}"
        
    return phone_str

def make_call(phone, gid):
    if not client:
        print("❌ Twilio Error: Client not initialized. Check .env")
        return

    formatted_phone = format_number(phone)
    if not formatted_phone:
        print("❌ Twilio Error: No phone number provided.")
        return

    try:
        print(f"📡 Twilio: Attempting call to {formatted_phone} for Request {gid}...")
        
        call = client.calls.create(
            to=formatted_phone,
            from_=FROM_NUMBER,
            url=f"{BASE_URL}/ivr/voice/{gid}",
            status_callback=f"{BASE_URL}/ivr/status/{gid}",
            status_callback_event=['completed', 'busy', 'no-answer', 'failed'],
            status_callback_method='POST'
        )
        
        print(f"✅ CALL SENT! SID: {call.sid}")

        # UPDATE ATTEMPTS
        sb = get_db()
        res = sb.table("Leave_request").select("attempts").eq("Req_id", gid).execute()
        current_attempts = 0
        if res.data:
            current_attempts = res.data[0].get("attempts") or 0

        sb.table("Leave_request").update({
            "attempts": current_attempts + 1,
        }).eq("Req_id", gid).execute()

        print("CALL SENT")

    except Exception as e:
        print("CALL FAILED:", e)