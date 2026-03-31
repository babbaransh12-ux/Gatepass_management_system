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
    # 1. Insert Parent
    parent_data = {
        "phone": "9876543210"
    }
    p_res = supabase.table("Parent").insert(parent_data).execute()
    parent_id = p_res.data[0]['id']
    print(f"Inserted Parent ID: {parent_id}")

    # 2. Insert Student
    student_data = {
        "AU_id": "H-2024-0001",
        "Name": "Test Student",
        "Room_no": "A-101",
        "Parent_id": parent_id
    }
    s_res = supabase.table("Student").insert(student_data).execute()
    student_id = s_res.data[0].get('id')
    print(f"Inserted Student: {student_data['AU_id']}")

    print("\n" + "="*40)
    print("CREDENTIALS CREATED SUCCESSFULLY")
    print("="*40)
    print(f"Username: {student_data['AU_id']}")
    print(f"Password: {parent_data['phone']}")
    print("="*40)

except Exception as e:
    print(f"Error: {e}")
