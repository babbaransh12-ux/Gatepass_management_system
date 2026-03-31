import os, sys, json
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.getcwd(), '.env'))
from backend.db import get_db

try:
    sb = get_db()
    
    res = sb.table("Leave_request").select("Req_id, AU_id, Destination, Days, Reason, leave_date, Status").in_("Status", ["Pending", "Parent_Approved"]).execute()
        
    data = res.data
    for req in data:
        # Fix: use comma-separated string (NOT two separate args) for Supabase select
        s_res = sb.table("Student").select("Name, Student_image, Room_no").eq("AU_id", req.get("AU_id")).execute()
        student = s_res.data[0] if s_res.data else {}
        name = student.get("Name") or "Unknown"
        req["student_name"] = name
        # Always provide a valid profile_url (Image.network() crashes on null)
        req["profile_url"] = student.get("Student_image") or f"https://ui-avatars.com/api/?name={name}&background=2D5AF0&color=fff"
        req["room"] = student.get("Room_no") or ""
        
        # Map Parent_Approved to Pending so Flutter enum doesn't crash
        if req.get("Status") == "Parent_Approved":
            req["Reason"] = f"(✅ Parent Approved) {req.get('Reason', '')}"
            req["Status"] = "Pending"
    
    print("\nFINAL PROCESSED DATA:")
    with open('debug_warden.json', 'w') as f:
        json.dump(data, f, indent=2)

except Exception as e:
    print("ERROR:", e)
