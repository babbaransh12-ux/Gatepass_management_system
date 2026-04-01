import os
from dotenv import load_dotenv
from pyngrok import ngrok

load_dotenv("../.env")

auth_token = os.environ.get("NGROK_AUTHTOKEN")
domain = os.environ.get("NGROK_DOMAIN")
port = 5000

print(f"Auth Token: {auth_token[:5]}...")
print(f"Domain: {domain}")

try:
    ngrok.set_auth_token(auth_token)
    if domain:
        url = ngrok.connect(port, domain=domain).public_url
    else:
        url = ngrok.connect(port).public_url
    print(f"SUCCESS: {url}")
except Exception as e:
    import traceback
    with open("ngrok_error.log", "w") as f:
        traceback.print_exc(file=f)
        f.write(f"\nERROR: {str(e)}")
    print("ERROR LOGGED TO ngrok_error.log")
finally:
    ngrok.kill()
