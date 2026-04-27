import os
import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from datetime import datetime, timedelta
from db import get_db
from services.gatepass_service import create_gatepass
from routes.auth_routes import get_current_user
from models import GatepassRequest

router = APIRouter(prefix="/student", tags=["student"])

@router.get("/profile/{student_id}")
def get_profile(student_id: str, current_user: dict = Depends(get_current_user)):
    try:
        # Security: Only allow student to see their own profile or a warden
        if current_user.get("role") == "Student" and current_user.get("user_id") != student_id:
            raise HTTPException(status_code=403, detail="Unauthorized access to profile")

        sb = get_db()
        res = sb.table("Student").select("Name, Room_no, Parent_id, Student_image, Department, Course, Email_id, Gender").eq("AU_id", student_id).execute()
        
        if not res.data and student_id.isdigit():
             res = sb.table("Student").select("Name, Room_no, Parent_id, Student_image, Department, Course, Email_id, Gender").eq("AU_id", int(student_id)).execute()
             
        if not res.data:
            return {
                "status": "error",
                "message": "Student not found",
                "id": student_id,
                "name": "Unregistered",
                "parents": []
            }
            
        s = res.data[0]
        parent_id = s.get("Parent_id")
        parents = []
        parent_raw = {}
        if parent_id:
            parent_res = sb.table("Parent").select("Father_Name, Father_Phone, Mother_Name, Mother_Phone, Guardian_Phone").eq("Parent_id", parent_id).execute()
            if parent_res.data:
                parent_raw = parent_res.data[0]
                p = parent_raw
                if p.get("Father_Name") and p.get("Father_Phone"):
                    parents.append({"name": p["Father_Name"], "Phone": p["Father_Phone"], "Relation": "Father"})
                if p.get("Mother_Name") and p.get("Mother_Phone"):
                    parents.append({"name": p["Mother_Name"], "Phone": p["Mother_Phone"], "Relation": "Mother"})
                if p.get("Guardian_Phone"):
                    parents.append({"name": "Guardian", "Phone": p["Guardian_Phone"], "Relation": "Guardian"})
        
        gender = s.get("Gender", "Male")
        try:
            warden_res = sb.table("Warden").select("Name, Mobile_no").eq("Gender", gender).limit(1).execute()
            w_data = warden_res.data[0] if warden_res.data else {}
            w_info = {"name": w_data.get("Name") or "Warden", "phone": w_data.get("Mobile_no") or ""}
        except Exception:
            try:
                # Fallback: column might be named differently
                warden_res = sb.table("Warden").select("*").eq("Gender", gender).limit(1).execute()
                w_data = warden_res.data[0] if warden_res.data else {}
                w_info = {"name": w_data.get("Name") or "Warden", "phone": w_data.get("Mobile_no") or w_data.get("Phone") or ""}
            except Exception:
                w_info = {"name": "Warden", "phone": ""}

        active_req = sb.table("Leave_request").select("Req_id, Status, qr_token").eq("AU_id", student_id).in_("Status", ["Pending", "Parent_Approved", "Warden_Approved", "Approved", "Exit"]).order("Req_id", desc=True).limit(1).execute()
        active_data = active_req.data[0] if active_req.data else {}
        active_id = active_data.get("Req_id")
        active_status = active_data.get("Status", "")

        reject_res = sb.table("Leave_request").select("*").eq("AU_id", student_id).eq("Status", "Rejected").order("Req_id", desc=True).limit(1).execute()
        
        last_rejection = None
        cooldown_remaining_ms = 0
        if reject_res.data:
            r = reject_res.data[0]
            created_raw = r.get("created_at")
            last_rejection = {"reason": r.get("Reason"), "timestamp": created_raw}
            try:
                # Handle both timetz ("08:00:00+00") and timestamptz ("2026-04-08T08:00:00+00:00")
                if created_raw and "T" in str(created_raw):
                    created_dt = datetime.fromisoformat(str(created_raw).split('+')[0])
                    cooldown_end = created_dt + timedelta(hours=6)
                    if cooldown_end > datetime.now():
                        cooldown_remaining_ms = int((cooldown_end - datetime.now()).total_seconds() * 1000)
            except Exception:
                pass

        # FETCH RECENT HISTORY (Acceptance/Rejection only)
        history_query = sb.table("Leave_request")\
            .select("*")\
            .eq("AU_id", student_id)\
            .in_("Status", ["Approved", "Rejected", "Completed", "Exit", "Entry"])\
            .order("Req_id", desc=True)\
            .limit(10)\
            .execute()

        # Perform 4-hour filter in Python due to 'time with time zone' DB type limitation
        recent_history = []
        now_utc = datetime.utcnow()
        from datetime import time
        for r in history_query.data:
            c_time_raw = r.get("created_at")
            if not c_time_raw:
                continue
            try:
                if "T" in c_time_raw:
                    dt = datetime.fromisoformat(c_time_raw.split('+')[0])
                else:
                    t_str = c_time_raw.split('+')[0]
                    t_obj = time.fromisoformat(t_str)
                    dt = datetime.combine(now_utc.date(), t_obj)
                    if dt > now_utc:
                        dt -= timedelta(days=1)
                
                if (now_utc - dt) <= timedelta(hours=4):
                    recent_history.append(r)
            except Exception as e:
                print(f"Time parse error: {e}")
                pass

        return {
            "status": "success",
            "id": student_id,
            "Room_no": s.get("Room_no"),
            "name": s.get("Name"),
            "profile_url": s.get("Student_image"),
            "department": s.get("Department"),
            "course": s.get("Course"),
            "email": s.get("Email_id"),
            "gender": gender,
            "parents": parents,
            "parent_info": parent_raw,
            "warden_info": w_info,
            "active_req_id": active_id,
            "active_status": active_status,
            "qr_token": active_data.get("qr_token"),
            "last_rejection": last_rejection,
            "cooldown_remaining_ms": cooldown_remaining_ms,
            "history": recent_history
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"❌ /student/profile/{student_id} error: {type(e).__name__}: {e}")
        if isinstance(e, HTTPException):
            raise
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/update-profile-pic")
@router.post("/upload-image")
async def update_profile_pic(
    student_id: Optional[str] = Form(None),
    image: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    try:
        final_student_id = student_id or current_user.get("user_id")
        if not final_student_id:
             raise HTTPException(status_code=400, detail="Student ID missing")
            
        file_bytes = await image.read()
        ext = image.filename.rsplit('.', 1)[1].lower() if '.' in image.filename else 'jpg'
        file_name = f"{final_student_id}_{uuid.uuid4().hex[:8]}.{ext}"
        
        sb = get_db()
        mimetype = image.content_type
        if mimetype == "application/octet-stream" or not mimetype:
            mimetype = "image/jpeg"
            if file_name.lower().endswith('.png'): mimetype = "image/png"
            elif file_name.lower().endswith('.webp'): mimetype = "image/webp"

        try:
            # Check if bucket exists/accessible by trying to upload
            sb.storage.from_("Student").upload(
                file_name,
                file_bytes,
                {"content-type": mimetype}
            )
        except Exception as storage_err:
            print(f"DEBUG: Supabase Storage Error: {storage_err}")
            # If upload failed, maybe bucket doesn't exist or RLS issue
            raise HTTPException(status_code=500, detail=f"Storage upload failed: {str(storage_err)}")
        
        public_url = sb.storage.from_("Student").get_public_url(file_name)
        
        # In some versions of supabase-py, get_public_url might return a string or an object
        # With 2.4.5 it should be a string, but let's be safe
        if not isinstance(public_url, str):
            public_url = getattr(public_url, "public_url", str(public_url))

        sb.table("Student").update({"Student_image": public_url}).eq("AU_id", final_student_id).execute()
        
        return {"status": "success", "message": "Profile picture updated successfully", "profile_url": public_url}
    except HTTPException:
        raise
    except Exception as e:
        print(f"DEBUG: Profile Pic Upload Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/request")
def request_gp(data: GatepassRequest, current_user: dict = Depends(get_current_user)):
    try:
        sid = data.student_id
        days_str = str(data.duration)
        
        res = create_gatepass(
            student_id=sid,
            destination=data.destination,
            reason=data.reason,
            days=days_str,
            leave_date=data.leave_date,
            contact=data.contact.lower() if data.contact else "father",
            language=data.language.lower() if data.language else "en"
        )
        if isinstance(res, dict) and res.get("status") == "success":
            return {"status": "success", "message": res["message"], "req_id": res["req_id"]}
        elif isinstance(res, dict):
             raise HTTPException(status_code=400, detail=res.get("message", "Failed to create gatepass"))
        return {"status": "success", "message": "Gatepass request submitted"}
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"❌ /student/request error: {type(e).__name__}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/status/{req_id}")
def check_status(req_id: int, current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        res = sb.table("Leave_request").select("Status").eq("Req_id", req_id).execute()
        if res.data:
            return {"status": "success", "request_status": res.data[0]["Status"]}
        raise HTTPException(status_code=404, detail="Request not found")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/active-pass/{student_id}")
def active_pass(student_id: str, current_user: dict = Depends(get_current_user)):
    try:
        print(f"🔍 DEBUG: Fetching active pass for {student_id}")
        sb = get_db()
        res = sb.table("Leave_request").select("*").eq("AU_id", student_id).in_("Status", ["Pending", "Parent_Approved", "Approved", "Exit"]).order("Req_id", desc=True).limit(1).execute()
        
        if res.data:
            print(f"✅ DEBUG: Found active pass: {res.data[0].get('Req_id')}")
            req = res.data[0]
            # No status remapping - return the true status so frontend stepper can advance
            return {"status": "success", "data": req}
        
        print(f"ℹ️ DEBUG: No active pass found for {student_id}")
        return {"status": "success", "data": None}
    except Exception as e:
        print(f"🔥 DEBUG: active_pass ERROR: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/history/{student_id}")
def history(student_id: str, current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        history_query = sb.table("Leave_request")\
            .select("*")\
            .eq("AU_id", student_id)\
            .in_("Status", ["Approved", "Rejected", "Completed", "Exit", "Entry"])\
            .order("Req_id", desc=True)\
            .limit(10)\
            .execute()
        
        recent_history = []
        now_utc = datetime.utcnow()
        from datetime import time, timedelta
        for r in history_query.data:
            c_time_raw = r.get("created_at")
            if not c_time_raw:
                continue
            try:
                if "T" in c_time_raw:
                    dt = datetime.fromisoformat(c_time_raw.split('+')[0])
                else:
                    t_str = c_time_raw.split('+')[0]
                    t_obj = time.fromisoformat(t_str)
                    dt = datetime.combine(now_utc.date(), t_obj)
                    if dt > now_utc:
                        dt -= timedelta(days=1)
                
                if (now_utc - dt) <= timedelta(hours=4):
                    recent_history.append(r)
            except Exception as e:
                pass
                
        return {"status": "success", "history": recent_history}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))