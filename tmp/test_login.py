import os
from dotenv import load_dotenv
from supabase import create_client
import json

load_dotenv(dotenv_path='../.env')
supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_ANON_KEY'))

print("=== ALL STUDENTS ===")
res = supabase.table("Student").select("AU_id, Name, Parent_id, device_id").execute()
print(json.dumps(res.data, indent=2))

print("\n=== ALL PARENTS ===")
res2 = supabase.table("Parent").select("*").execute()
print(json.dumps(res2.data, indent=2))
