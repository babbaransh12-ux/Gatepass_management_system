import os
from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Query
from twilio.rest import Client
from db import get_db
from routes.auth_routes import get_current_user

router = APIRouter(prefix="/qr", tags=["qr"])

def get_message(lang, action, name):
    msgs = {
        "en": {"exit": f"Your ward {name} has officially left the university campus.", "entry": f"Your ward {name} has safely entered the university campus."},
        "hi": {"exit": f"आपके बच्चे {name} ने विश्वविद्यालय परिसर छोड़ दिया है।", "entry": f"आपके बच्चे {name} ने सुरक्षित रूप से विश्वविद्यालय परिसर में प्रवेश किया है।"},
        "pa": {"exit": f"ਤੁਹਾਡੇ ਬੱਚੇ {name} ਨੇ ਯੂਨੀਵਰਸਿਟੀ ਕੈਂਪਸ ਛੱਡ ਦਿੱਤਾ ਹੈ।", "entry": f"ਤੁਹਾਡੇ ਬੱਚੇ {name} ਨੇ ਯੂਨੀਵਰਸਿਟੀ ਕੈਂਪਸ ਵਿੱਚ ਸੁਰੱਖਿਅਤ ਦਾਖਲਾ ਲਿਆ ਹੈ।"}
    }
    return msgs.get(lang, msgs["en"]).get(action)

def send_notification(phone, txt):
    try:
        sid = os.getenv("TWILIO_ACCOUNT_SID")
        token = os.getenv("TWILIO_AUTH_TOKEN")
        from_phone = os.getenv("TWILIO_WHATSAPP_NUMBER") or os.getenv("TWILIO_PHONE_NUMBER")
        use_whatsapp = os.getenv("USE_WHATSAPP", "false").lower() == "true"
        
        if phone and not str(phone).startswith('+'):
            phone_str = str(phone).strip()
            if len(phone_str) == 10:
                phone = f"+91{phone_str}"
            else:
                phone = f"+{phone_str}"
        else:
            phone = str(phone).strip()

        if use_whatsapp:
            if not str(from_phone).startswith('whatsapp:'):
                 from_phone = f"whatsapp:{from_phone}"
            if not str(phone).startswith('whatsapp:'):
                 phone = f"whatsapp:{phone}"

        if sid and token and from_phone:
            client = Client(sid, token)
            client.messages.create(body=txt, from_=from_phone, to=phone)
            print(f"✅ WhatsApp/SMS Sent to {phone}")
    except Exception as e:
        print(f"❌ Notification Error: {e}")

@router.get("/scan/{token}")
def get_scan(token: str, current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        
        if len(token) < 15:
            res = sb.table("Leave_request").select("*").eq("AU_id", token).in_("Status", ["Approved", "Exit", "Emergency", "Completed", "Warden_Approved"]).order("Req_id", desc=True).limit(1).execute()
        else:
            res = sb.table("Leave_request").select("*").eq("qr_token", token).execute()
            
        if not res.data:
            return {"status": "error", "message": "Invalid QR or No Active Pass"}

        req = res.data[0]
        au_id = req.get("AU_id")
        
        # Get Student Profile
        s_res = sb.table("Student").select("Name, AU_id, Student_image, Department, Course").eq("AU_id", au_id).execute()
        student = s_res.data[0] if s_res.data else {}
        
        return {
            "status": "success",
            "request": req,
            "student": {
                "name": student.get("Name"),
                "uid": student.get("AU_id"),
                "photo": student.get("Student_image"),
                "dept": student.get("Department")
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/scan/{token}")
def verify_scan(token: str, action: Optional[str] = Query(None), current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        
        if len(token) < 15:
            res = sb.table("Leave_request").select("*").eq("AU_id", token).in_("Status", ["Approved", "Exit", "Emergency", "Completed", "Warden_Approved"]).order("Req_id", desc=True).limit(1).execute()
        else:
            res = sb.table("Leave_request").select("*").eq("qr_token", token).execute()
        
        if not res.data:
            return {"status": "error", "message": "Invalid QR"}

        req = res.data[0]
        req_id = req.get("Req_id")
        au_id = req.get("AU_id")
        current_status = req.get("Status", "Approved")

        # Determine action from current Status if not explicitly passed
        if not action:
            if current_status in ("Approved", "Emergency", "Warden_Approved"):
                action = "exit"
            elif current_status == "Exit":
                action = "entry"
            else:
                return {"status": "error", "message": f"Pass already {current_status.lower()}"}

        # 🛡️ VALIDATION: Enforce strict sequence and limit one exit/entry
        if action == "exit":
            if current_status in ("Exit", "Completed"):
                return {"status": "error", "message": "Exit already marked for this pass"}
            if current_status not in ("Approved", "Emergency", "Warden_Approved"):
                return {"status": "error", "message": f"Cannot mark exit. Status: {current_status}"}
        elif action == "entry":
            if current_status == "Completed":
                return {"status": "error", "message": "Entry already marked for this pass"}
            if current_status != "Exit":
                return {"status": "error", "message": "Cannot mark entry. Student must exit first."}

        # Status-only update
        new_status = "Exit" if action == "exit" else "Completed"
        update_res = sb.table("Leave_request").update({"Status": new_status}).eq("Req_id", req_id).execute()
        
        if not update_res.data:
            print(f"❌ Database Update Failed for Req_id {req_id}")
            return {"status": "error", "message": "Database update failed"}

        print(f"✅ Pass {req_id} updated to {new_status}")

        try:
            from datetime import timezone
            gate_log_payload = {
                "req_id": req_id,
                "stu_id": au_id,
                "Action": action,
                "Timestamp": datetime.now(timezone.utc).isoformat(),
                "Gaurd_id": current_user.get("user_id", 0) or 0
            }
            sb.table("Gate_log").insert(gate_log_payload).execute()
            print(f"✅ Gate_log recorded: {action} for {au_id}")
        except Exception as e:
            print(f"❌ Gate_log insert failed: {e}")

        # Notify Parent
        try:
            current_parent = req.get("current_parent") or "Father"
            student_res = sb.table("Student").select("Name, Parent_id").eq("AU_id", au_id).execute()
            if student_res.data:
                s = student_res.data[0]
                name = s.get("Name")
                parent_id = s.get("Parent_id")
                if parent_id:
                    p_res = sb.table("Parent").select("Father_Phone, Mother_Phone, Guardian_Phone").eq("Parent_id", parent_id).execute()
                    if p_res.data:
                        p_data = p_res.data[0]
                        phone = None
                        if current_parent.lower() == "mother":
                            phone = p_data.get("Mother_Phone")
                        elif current_parent.lower() == "guardian":
                            phone = p_data.get("Guardian_Phone")
                        else:
                            phone = p_data.get("Father_Phone")
                        
                        if not phone:
                            phone = p_data.get("Father_Phone") or p_data.get("Mother_Phone") or p_data.get("Guardian_Phone")
                        
                        print(f"📱 Sending WhatsApp to {phone} for {name} — action={action}")
                        if phone:
                            send_notification(phone, get_message("en", action, name))
                        else:
                            print(f"⚠️ No phone found for parent_id={parent_id}")
                    else:
                        print(f"⚠️ No parent record found for parent_id={parent_id}")
                else:
                    print(f"⚠️ No parent_id linked to student {au_id}")
            else:
                print(f"⚠️ Student {au_id} not found for notification")
        except Exception as e:
            print(f"❌ Notification error: {e}")

        return {"status": "success", "message": f"{action.capitalize()} recorded", "action": action}
        
    except Exception as e:
        print(f"Verify scan error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/undo-scan/{token}")
def undo_scan(token: str, current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        if len(token) < 15:
            res = sb.table("Leave_request").select("*").eq("AU_id", token).in_("Status", ["Exit", "Completed"]).order("Req_id", desc=True).limit(1).execute()
        else:
            res = sb.table("Leave_request").select("*").eq("qr_token", token).execute()
            
        if not res.data: return {"status": "error", "message": "No active pass to undo"}
        
        req = res.data[0]
        req_id = req.get("Req_id")
        current_status = req.get("Status")
        
        if current_status == "Completed":
            # Revert to Exit status and remove entry log
            sb.table("Leave_request").update({"Status": "Exit"}).eq("Req_id", req_id).execute()
            sb.table("Gate_log").delete().eq("req_id", req_id).eq("Action", "entry").execute()
            return {"status": "success", "message": "Entry scan undone"}
        elif current_status == "Exit":
            # Revert to Approved status and remove exit log
            sb.table("Leave_request").update({"Status": "Approved"}).eq("Req_id", req_id).execute()
            sb.table("Gate_log").delete().eq("req_id", req_id).eq("Action", "exit").execute()
            return {"status": "success", "message": "Exit scan undone"}
        
        return {"status": "error", "message": "Cannot undo this pass state"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/active-emergencies")
def active_emergencies(current_user: dict = Depends(get_current_user)):
    # Disabled polling popup to prevent lag and false triggers. Guards use the manual 'Emergency Search' button instead.
    return []

@router.get("/recent-logs")
def get_recent_logs(current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        # Only show logs from the last 6 hours
        from datetime import datetime, timedelta, timezone
        six_hours_ago = (datetime.now(timezone.utc) - timedelta(hours=6)).isoformat()
        
        res = sb.table("Gate_log").select("*, Student:stu_id(Name, Student_image)")\
            .gte("Timestamp", six_hours_ago)\
            .order("Timestamp", desc=True).limit(20).execute()
        data = res.data or []
        result = []
        for row in data:
            student = row.get("Student") or {}
            name = student.get("Name") or "Unknown"
            image = student.get("Student_image")
            # Generate fallback avatar if no image
            if not image:
                image = f"https://ui-avatars.com/api/?name={name}&background=2D5AF0&color=fff"
            result.append({
                "student_name": name,
                "student_image": image,
                "action": (row.get("action") or "Unknown").capitalize(),
                "timestamp": row.get("timestamp")
            })
        return result
    except Exception as e:
        print(f"❌ recent-logs error: {e}")
        return []