import os
from supabase import create_client, Client

# Use simple global variable for client instance
_supabase: Client = None

def init_db():
    global _supabase
    try:
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_ANON_KEY")
        if not url or not key:
            print("WARNING: SUPABASE_URL or SUPABASE_ANON_KEY environment variables are missing.")
            return

        _supabase = create_client(url, key)
        print("Connected to Supabase DB successfully.")
    except Exception as e:
        print(f"Error connecting to Supabase: {e}")

def get_db() -> Client:
    global _supabase
    if _supabase is None:
        init_db()
    return _supabase