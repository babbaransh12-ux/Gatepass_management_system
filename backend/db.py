import os
from supabase import create_client, Client

# Use simple global variable for client instance
_supabase: Client = None

def init_db():
    global _supabase
    try:
        url = os.getenv("SUPABASE_URL", "").strip()
        
        # Use ONLY the Service Role Key — bypasses RLS for all backend operations
        service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        
        if not url or not service_key:
            print("ERROR: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing in .env!")
            return

        _supabase = create_client(url, service_key)
        print("✅ Connected to Supabase DB with Service Role Key (RLS bypassed).")
    except Exception as e:
        print(f"Error connecting to Supabase: {e}")

def get_db() -> Client:
    global _supabase
    if _supabase is None:
        init_db()
    return _supabase