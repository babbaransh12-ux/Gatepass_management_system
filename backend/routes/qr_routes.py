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
            res = sb.table("Leave_request").select("*").eq("AU_id", token).in_("Status", ["Approved", "Exit", "Emergency"]).order("Req_id", desc=True).limit(1).execute()
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
            res = sb.table("Leave_request").select("*").eq("AU_id", token).in_("Status", ["Approved", "Exit", "Emergency"]).order("Req_id", desc=True).limit(1).execute()
        else:
            res = sb.table("Leave_request").select("*").eq("qr_token", token).execute()
        
        if not res.data:
            return {"status": "error", "message": "Invalid QR"}

        req = res.data[0]
        req_id = req.get("Req_id")
        au_id = req.get("AU_id")
        
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        if not action:
            if not req.get("exit_time"):
                action = "exit"
            elif not req.get("entry_time"):
                action = "entry"
            else:
                return {"status": "error", "message": "Gatepass already completed"}

        update_payload = {"Status": "Exit" if action == "exit" else "Deactivated"}
        
        if action == "exit":
            update_payload["exit_time"] = now
        else:
            update_payload["entry_time"] = now

        try:
            sb.table("Leave_request").update(update_payload).eq("Req_id", req_id).execute()
        except:
            fb_status = "Exit" if action == "exit" else "Deactivated"
            sb.table("Leave_request").update({"Status": fb_status}).eq("Req_id", req_id).execute()

        try:
            sb.table("Gate_log").insert({
                "req_id": req_id,
                "stu_id": au_id,
                "Action": action,
                "Timestamp": now
            }).execute()
        except Exception as e:
            print(f"Gate log error (ignoring): {e}")

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
                            
                        if phone:
                            send_notification(phone, get_message("en", action, name))
        except Exception as e:
            print(f"Notification error (ignoring): {e}")

        return {"status": "success", "message": f"{action.capitalize()} recorded", "action": action}
        
    except Exception as e:
        print(f"Verify scan error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/undo-scan/{token}")
def undo_scan(token: str, current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        res = sb.table("Leave_request").select("*").eq("qr_token", token).execute()
        if not res.data: return {"status": "error", "message": "Not found"}
        
        req = res.data[0]
        req_id = req.get("Req_id")
        
        if req.get("exit_time"):
            sb.table("Leave_request").update({"exit_time": None, "Status": "Exit"}).eq("Req_id", req_id).execute()
        elif req.get("entry_time"):
            sb.table("Leave_request").update({"entry_time": None, "Status": "Approved"}).eq("Req_id", req_id).execute()
            
        return {"status": "success", "message": "Last scan undone"}
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
        res = sb.table("Gate_log").select("*, Student:stu_id(Name, Student_image)").order("timestamp", desc=True).limit(20).execute()
        data = res.data or []
        return [{
            "student_name": row.get("Student", {}).get("Name") or "Unknown",
            "student_image": row.get("Student", {}).get("Student_image"),
            "action": row.get("action", "Unknown").capitalize(),
            "timestamp": row.get("timestamp")
        } for row in data]
    except Exception as e:
        return []