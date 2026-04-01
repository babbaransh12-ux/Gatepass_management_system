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

def send_sms(phone, txt):
    try:
        sid = os.getenv("TWILIO_ACCOUNT_SID")
        token = os.getenv("TWILIO_AUTH_TOKEN")
        from_phone = os.getenv("TWILIO_PHONE_NUMBER")
        
        if sid and token and from_phone:
            client = Client(sid, token)
            client.messages.create(body=txt, from_=from_phone, to=phone)
            print(f"SMS Sent to {phone}")
    except Exception as e:
        print(f"SMS Error: {e}")

@router.api_route("/scan/{token}", methods=["GET", "POST"])
def scan(token: str, action: Optional[str] = Query(None), current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        res = sb.table("Leave_request").select("Req_id, AU_id, Status").eq("qr_token", token).execute()
        
        if not res.data:
            return {"status": "error", "message": "Invalid QR"}

        row = res.data[0]
        req_id = row.get("Req_id")
        au_id = row.get("AU_id")
        status_str = row.get("Status")

        if status_str == "Expired":
            return {"status": "error", "message": "QR expired"}

        try:
            log_res = sb.table("Gate_log").select("action, scanned_at, Timestamp").eq("leave_request_id", req_id).execute()
        except Exception:
            try:
                log_res = sb.table("Gate_log").select("*").eq("req_id", req_id).execute()
            except Exception:
                log_res = None
        
        sc = len(log_res.data) if log_res else 0
        
        if not action:
            if sc == 0:
                action = "exit"
            elif sc == 1:
                action = "entry"
            else:
                return {"status": "error", "message": "QR expired or already used"}

        if sc > 0:
            last_log = log_res.data[-1]
            last_time_str = last_log.get("scanned_at") or last_log.get("Timestamp")
            if last_time_str:
                try:
                    if 'T' in last_time_str:
                        last_time = datetime.fromisoformat(last_time_str.split('+')[0])
                    else:
                        last_time = datetime.strptime(last_time_str, "%Y-%m-%d %H:%M:%S")
                    
                    if (datetime.now() - last_time).total_seconds() < 60:
                        return {"status": "error", "message": "Wait 60s before next scan."}
                except Exception as e:
                    print(f"Cooldown check error: {e}")

        student_res = sb.table("Student").select("Name, Parent_id, AU_id, Student_image").eq("AU_id", au_id).execute()
        name = "Student"
        image_url = None
        phone = None
        lang = "en"
        
        if student_res.data:
            s_row = student_res.data[0]
            name = s_row.get("Name", "Student")
            image_url = s_row.get("Student_image")
            parent_id = s_row.get("Parent_id")
            if parent_id:
                parent_res = sb.table("Parent").select("Father_Phone, Mother_Phone, Guardian_Phone, language").eq("Parent_id", parent_id).execute()
                if parent_res.data:
                    p_data = parent_res.data[0]
                    phone = p_data.get("Father_Phone") or p_data.get("Mother_Phone") or p_data.get("Guardian_Phone")
                    lang = p_data.get("language") or "en"

        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        # Robust Gate_log insertion
        log_success = False
        try:
            sb.table("Gate_log").insert({"leave_request_id": req_id, "action": action, "scanned_at": now}).execute()
            log_success = True
        except Exception as e1:
            print(f"DEBUG: Gate_log primary insert failed: {e1}")
            try:
                sb.table("Gate_log").insert({"req_id": req_id, "Action": action, "Timestamp": now}).execute()
                log_success = True
            except Exception as e2:
                print(f"DEBUG: Gate_log fallback insert failed: {e2}")

        # Update Request Status
        try:
            if action == "exit":
                sb.table("Leave_request").update({"Status": "Exit"}).eq("Req_id", req_id).execute()
            elif action == "entry":
                sb.table("Leave_request").update({"Status": "Expired"}).eq("Req_id", req_id).execute()
        except Exception as status_err:
            print(f"DEBUG: Status update failed: {status_err}")

        if phone:
            sms_text = get_message(lang, action, name)
            print(f"📡 DEBUG: Sending SMS to {phone}: {sms_text}")
            send_sms(phone, sms_text)

        return {
            "status": "success", 
            "message": f"{action.capitalize()} recorded.", 
            "scan_count": sc + 1,
            "student_name": name,
            "student_id": au_id,
            "student_image": image_url
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/active-emergencies")
def active_emergencies(current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        try:
            res = sb.table("Leave_request").select("Req_id, AU_id, Reason, qr_token, Status").eq("type", "Emergency").eq("Status", "Approved").execute()
        except Exception:
            res = sb.table("Leave_request").select("Req_id, AU_id, Reason, qr_token, Status").eq("Status", "Approved").execute()
        
        data = res.data
        enriched = []
        for row in data:
            if not row.get("qr_token"):
                continue
            
            au_id = row.get("AU_id")
            s_res = sb.table("Student").select("Name, Room_no, Student_image").eq("AU_id", au_id).execute()
            student = s_res.data[0] if s_res.data else {}
            name = student.get("Name") or "Student"
            
            enriched.append({
                "req_id": row.get("Req_id"),
                "AU_id": au_id,
                "student_name": name,
                "room": student.get("Room_no") or "N/A",
                "student_image": student.get("Student_image") or f"https://ui-avatars.com/api/?name={name}&background=E53935&color=fff",
                "reason": row.get("Reason") or "Emergency",
                "qr_token": row.get("qr_token"),
                "status": row.get("Status"),
            })
        
        return enriched
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))