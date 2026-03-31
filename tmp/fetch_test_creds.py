import os
from dotenv import load_dotenv
from supabase import create_client

load_dotenv(dotenv_path='../.env')

supabase_url = os.getenv('SUPABASE_URL')
supabase_key = os.getenv('SUPABASE_ANON_KEY')

if not supabase_url or not supabase_key:
    print("Error: SUPABASE_URL or SUPABASE_ANON_KEY not found in .env")
    exit(1)

supabase = create_client(supabase_url, supabase_key)

try:
    # Fetch some students
    response = supabase.table('Student').select('AU_id, Parent_id').limit(5).execute()
    students = response.data

    # Fetch parents to get phone numbers
    parent_ids = [s['Parent_id'] for s in students if s['Parent_id']]
    if parent_ids:
        parent_resp = supabase.table('Parent').select('id, phone').in_('id', parent_ids).execute()
        parent_map = {p['id']: p['phone'] for p in parent_resp.data}
    else:
        parent_map = {}

    print("\n" + "="*40)
    print("STUDENT LOGIN CREDENTIALS for TESTING")
    print("="*40)
    print(f"{'AU_id (Username)':<20} | {'Parent Phone (Password)':<20}")
    print("-" * 45)
    
    for s in students:
        au_id = s.get('AU_id', 'N/A')
        parent_id = s.get('Parent_id')
        password = parent_map.get(parent_id, 'N/A')
        print(f"{au_id:<20} | {password:<20}")
    
    print("="*40)

except Exception as e:
    print(f"Error fetching data: {e}")
