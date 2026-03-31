import sys, os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from db import get_db
from datetime import datetime, timedelta
from services.twilio_service import make_call

def retry_calls():
    try:
        sb = get_db()
        # SUPABASE SYNC: Leave_request uses 'Req_id' and 'AU_id' (Capitalized)
        res = sb.table("Leave_request").select("Req_id, AU_id, Status").eq("Status", "Pending").execute()
        
        data = res.data if res.data else []
        now = datetime.now()

        for d in data:
            gid = d.get("Req_id")
            au_id = d.get("AU_id")
            # Note: Adding attempt/timer logic here requires checking specific columns, 
            # for now we focus on data fetch stability.
            
            # Skip if no ID or AU_id
            if not gid or not au_id:
                continue

            # Unified guardian contact fetching
            phone = None
            student_res = sb.table("Student").select("Parent_id").eq("AU_id", au_id).execute()
            if student_res.data:
                parent_id = student_res.data[0].get("Parent_id")
                if parent_id:
                    parent_res = sb.table("Parent").select("Father_Phone").eq("Parent_id", parent_id).execute()
                    if parent_res.data:
                        phone = parent_res.data[0].get("Father_Phone")

            if phone:
                try:
                    make_call(phone, gid)
                except Exception as e:
                    print(f"Retry call failed for {gid}: {e}")

    except Exception as e:
        print("Error checking retries:", e)