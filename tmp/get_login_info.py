import os
from dotenv import load_dotenv
from supabase import create_client

# Load from root .env
load_dotenv(".env")

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_KEY")

if not url or not key:
    print("Error: Missing SUPABASE_URL or SUPABASE_KEY in .env")
    exit(1)

sb = create_client(url, key)

# Fetch students
s_res = sb.table("Student").select("AU_id, Parent_id, Name").limit(5).execute()
students = s_res.data
print("\n--- STUDENT LOGIN INFO ---")
print(f"{'Name':<20} | {'AU ID (Username)':<15} | {'Father Phone (Password)'}")
print("-" * 65)

for s in students:
    p_id = s.get("Parent_id")
    if p_id:
        p_res = sb.table("Parent").select("Father_Phone").eq("Parent_id", p_id).execute()
        f_phone = p_res.data[0].get("Father_Phone", "N/A") if p_res.data else "N/A"
        print(f"{s['Name']:<20} | {s['AU_id']:<15} | {f_phone}")
    else:
        print(f"{s['Name']:<20} | {s['AU_id']:<15} | No Parent Linked")

print("-" * 65)
