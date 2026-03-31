import os
from dotenv import load_dotenv
from supabase import create_client, Client

# Load .env from root
dotenv_path = os.path.join(os.path.dirname(__file__), ".env")
load_dotenv(dotenv_path)

def verify_supabase():
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_ANON_KEY")
    
    if not url or not key:
        print("❌ Error: SUPABASE_URL or SUPABASE_ANON_KEY is missing from .env")
        return False
    
    try:
        supabase: Client = create_client(url, key)
        # Try a simple query
        res = supabase.table("Student").select("count", count="exact").limit(1).execute()
        print(f"✅ Supabase Connection Successful! Found {res.count} students.")
        return True
    except Exception as e:
        print(f"❌ Supabase Connection Failed: {e}")
        return False

if __name__ == "__main__":
    verify_supabase()
