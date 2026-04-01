import sys, os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from db import get_db
from services.twilio_service import make_call
from datetime import datetime, timedelta

def create_gatepass(student_id, destination, reason, days, contact, language, leave_date=None):
    try:
        sb = get_db()
        
        # 🛡️ 1. CHECK ACTIVE GATEPASS (Locked if Pending, Approved, or Outside)
        active_res = sb.table("Leave_request").select("Status").eq("AU_id", student_id).in_("Status", ["Pending", "Parent_Approved", "Warden_Approved", "Approved", "Exit"]).execute()
        if active_res.data:
            return {"status": "error", "message": "You already have an active leave request. Please track its status."}

        # ⏱️ 2. CHECK 6-HOUR COOLDOWN (If last request was Rejected)
        last_reject = sb.table("Leave_request").select("created_at").eq("AU_id", student_id).eq("Status", "Rejected").order("Req_id", desc=True).limit(1).execute()
        if last_reject.data:
            try:
                # Remove timezone for simple compares
                created_str = last_reject.data[0]["created_at"].split('+')[0]
                created_dt = datetime.fromisoformat(created_str)
                cooldown_end = created_dt + timedelta(hours=6)
                
                if cooldown_end > datetime.now():
                    remaining = cooldown_end - datetime.now()
                    hours, remainder = divmod(int(remaining.total_seconds()), 3600)
                    minutes, _ = divmod(remainder, 60)
                    return {
                        "status": "error", 
                        "message": f"Cooldown Active: You can submit another request in {hours}h {minutes}m."
                    }
            except Exception as e:
                print(f"Cooldown calc failed: {e}")

        # 3. FETCH STUDENT
        # SUPABASE SYNC: AU_id is column, Name, Parent_id are Capitalized
        student_res = sb.table("Student").select("Name, AU_id, Parent_id, Gender").eq("AU_id", student_id).execute()
        
        if not student_res.data:
            return {"status": "error", "message": "Student not found"}
            
        s = student_res.data[0]
        parent_id = s.get("Parent_id")
        
        # check parent phone
        # FETCH PARENT CONTACT (Case-sensitive matching with Supabase)
        phone = None
        if parent_id:
            parent_res = sb.table("Parent").select("Father_Phone, Mother_Phone, Guardian_Phone").eq("Parent_id", parent_id).execute()
            if parent_res.data:
                p = parent_res.data[0]
                # Priority: Father -> Mother -> Guardian
                phone = p.get("Father_Phone") or p.get("Mother_Phone") or p.get("Guardian_Phone")
                # Log what we found
                print(f"DEBUG: Found Phone: {phone}")
            else:
                print("DEBUG: No Parent contact found for this student.")

        # Use today as fallback if leave_date not provided
        from datetime import date
        final_leave_date = leave_date or date.today().isoformat()

        # SMART ROUTING: Fetch Warden based on Gender from Database
        gender = s.get("Gender", "Male")
        # Check Warden table for a match (either warden_id or Warden_id depending on column name)
        warden_lookup = sb.table("Warden").select("*").eq("Gender", gender).limit(1).execute()
        
        if warden_lookup.data:
            # Fallback to integer 1 if ID lookup fails
            raw_vid = warden_lookup.data[0].get("warden_id") or warden_lookup.data[0].get("Warden_id")
            try:
                assigned_warden = int(raw_vid)
            except:
                assigned_warden = 1
        else:
            # Fallback to a default if no gender-specific warden exists
            assigned_warden = 1 
        
        print(f"DEBUG: Routing to Warden {assigned_warden} for gender {gender}")

        # CONVERT DURATION
        try:
            if isinstance(days, str) and "hour" in days.lower():
                val = float(days.split()[0])
                days_val = val / 24.0
            else:
                days_val = float(days)
        except:
            days_val = 1.0

        base_insert = {
            "AU_id": student_id,
            "Destination": destination,
            "Reason": reason,
            "Days": days_val,
            "Status": "Pending",
            "leave_date": final_leave_date,
            "Warden_id": assigned_warden,
            "attempts": 1,
            "current_parent": "Father",
            "language": language
        }
        
        # Safe addition of 'type' - falls back if column doesn't exist yet
        try:
            insert_res = sb.table("Leave_request").insert({**base_insert, "type": "Standard"}).execute()
        except Exception as e:
            print(f"Schema Warning: 'type' column not found, falling back. Error: {e}")
            insert_res = sb.table("Leave_request").insert(base_insert).execute()

        if insert_res.data:
            # SUPABASE SYNC: Leave_request uses Req_id (Capitalized)
            req_id = insert_res.data[0].get("Req_id")
            if phone and req_id:
                make_call(phone, req_id)
            else:
                print(f"⚠️ Warning: Missing phone ({phone}) or req_id ({req_id}). Skipping Twilio.")
            return {"status": "success", "req_id": req_id, "message": f"Request created and routed to {gender} Warden"}
        else:
            return {"status": "error", "message": "Database Insert Failed (No data returned)"}
            
    except Exception as e:
        print("Error creating gatepass:", e)
        raise Exception(f"Database error: {e}")