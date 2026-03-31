import os
from dotenv import load_dotenv
from supabase import create_client

load_dotenv(".env")

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_ANON_KEY")
sb = create_client(url, key)

student_id = "247106033"
res = sb.table("Student").select("Name, Parent_id").eq("AU_id", student_id).execute()

if res.data:
    student = res.data[0]
    parent_id = student.get("Parent_id")
    print(f"Student: {student['Name']}, Parent ID: {parent_id}")
    
    if parent_id:
        parent_res = sb.table("Parent").select("Phone").eq("Parent_id", parent_id).execute()
        if parent_res.data:
            print(f"Parent Phone (Password): {parent_res.data[0]['Phone']}")
        else:
            print("Parent record not found.")
    else:
        print("No Parent ID mapped.")
else:
    print(f"Student {student_id} not found.")
