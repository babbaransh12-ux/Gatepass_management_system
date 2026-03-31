import os
from dotenv import load_dotenv
from twilio.rest import Client

# Load .env from root
dotenv_path = os.path.join(os.path.dirname(__file__), ".env")
load_dotenv(dotenv_path)

def verify_twilio():
    sid = os.getenv("TWILIO_ACCOUNT_SID")
    token = os.getenv("TWILIO_AUTH_TOKEN")
    phone = os.getenv("TWILIO_PHONE_NUMBER")
    
    if not sid or not token or not phone:
        print("❌ Error: Twilio environment variables are missing from .env")
        return False
    
    try:
        client = Client(sid, token)
        account = client.api.accounts(sid).fetch()
        print(f"✅ Twilio Connection Successful! Account Status: {account.status}")
        return True
    except Exception as e:
        print(f"❌ Twilio Connection Failed: {e}")
        return False

if __name__ == "__main__":
    verify_twilio()
