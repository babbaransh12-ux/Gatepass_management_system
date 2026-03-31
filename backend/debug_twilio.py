import os
from dotenv import load_dotenv
from twilio.rest import Client

def test_twilio():
    load_dotenv()
    
    account_sid = os.getenv('TWILIO_ACCOUNT_SID')
    auth_token = os.getenv('TWILIO_AUTH_TOKEN')
    from_number = os.getenv('TWILIO_PHONE_NUMBER')
    
    print("--- Twilio Diagnostic Tool ---")
    print(f"Account SID: {account_sid[:5]}... (Loaded: {bool(account_sid)})")
    print(f"Auth Token: {auth_token[:5]}... (Loaded: {bool(auth_token)})")
    print(f"From Number: {from_number} (Loaded: {bool(from_number)})")
    
    if not all([account_sid, auth_token, from_number]):
        print("❌ ERROR: Missing environment variables! Check backend/.env")
        return

    try:
        client = Client(account_sid, auth_token)
        # Test 1: Fetch account info
        account = client.api.accounts(account_sid).fetch()
        print(f"✅ Connection Success! Account Name: {account.friendly_name}")
        
        # Test 2: Check incoming phone numbers
        numbers = client.incoming_phone_numbers.list(limit=1)
        if numbers:
            print(f"✅ Verified Phone Number: {numbers[0].phone_number}")
        else:
            print("⚠️ No active Twilio numbers found in this account.")
            
    except Exception as e:
        print(f"❌ CONNECTION FAILED: {str(e)}")

if __name__ == "__main__":
    test_twilio()
