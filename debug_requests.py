import os, sys, json
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.getcwd(), '.env'))
from backend.db import get_db

try:
    sb = get_db()
    
    print("--- PENDING REQUESTS IN DB ---")
    res = sb.table('Leave_request').select('Status, Req_id, AU_id').in_('Status', ['Pending', 'Parent_Approved']).execute()
    print(res.data)
    
    print("\n--- ALL REQUESTS ---")
    all_res = sb.table('Leave_request').select('Status, Req_id, AU_id, type').order('Req_id', desc=True).limit(5).execute()
    print(all_res.data)

except Exception as e:
    print("ERROR:", e)
