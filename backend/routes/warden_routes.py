import os
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from datetime import datetime, timedelta, timezone
import pytz
from db import get_db
from services.qr_service import generate_qr
from routes.auth_routes import get_current_user
from models import WardenActionRequest, EmergencyPassRequest, UpdateParentRequest

router = APIRouter(prefix="/warden", tags=["warden"])

@router.get("/pending")
def get_pending(current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        # GENDER-BASED ROUTING: Fetch ALL Parent_Approved requests, then filter by matching student gender.
        # This works even when Warden_id is not pre-assigned on the Leave_request.

        warden_gender = current_user.get("gender")  # e.g., "Male" or "Female"

        # 1. Fetch ALL Parent_Approved requests (no Warden_id filter)
        res = sb.table("Leave_request").select("Req_id, AU_id, Destination, Days, Reason, leave_date, Status, Warden_id")\
            .eq("Status", "Parent_Approved")\
            .execute()
        
        data = []
        for req in res.data:
            # 2. Join with Student to check Gender
            s_res = sb.table("Student").select("Name, Student_image, Room_no, Gender").eq("AU_id", req.get("AU_id")).execute()
            student = s_res.data[0] if s_res.data else {}
            
            # 3. Gender-based routing: skip if student gender doesn't match this warden's gender
            student_gender = student.get("Gender")
            if warden_gender and student_gender and student_gender != warden_gender:
                continue

            name = student.get("Name") or "Unknown"
            req["student_name"] = name
            req["profile_url"] = student.get("Student_image") or f"https://ui-avatars.com/api/?name={name}&background=2D5AF0&color=fff"
            req["room"] = student.get("Room_no") or ""
            
            # Map Parent_Approved to Pending so Flutter enum doesn't crash
            req["Reason"] = f"(Parent Approved) {req.get('Reason', '')}"
            req["Status"] = "Pending"
            
            data.append(req)

        print(f"✅ /warden/pending → {len(data)} requests for gender={warden_gender}")
        return data
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"❌ /warden/pending error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/active-passes")
def get_active_passes(current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        # Find leaves that are currently Approved, Exit, or Emergency (actively off-campus or in-progress)
        res = sb.table("Leave_request").select("Req_id, AU_id, Destination, Days, created_at, Status, type").in_("Status", ["Approved", "Exit", "Emergency", "Warden_Approved"]).execute()
        
        data = res.data
        for req in data:
            s_res = sb.table("Student").select("Name", "Student_image").eq("AU_id", req.get("AU_id")).execute()
            req["student_name"] = s_res.data[0].get("Name") if s_res.data else "Unknown"
            req["profile_url"] = s_res.data[0].get("Student_image") if s_res.data else None
            
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/approve/{gatepass_id}")
def approve(gatepass_id: int, current_user: dict = Depends(get_current_user)):
    try:
        token, _ = generate_qr()

        sb = get_db()
        res = sb.table("Leave_request").update({
            "Status": "Approved",
            "qr_token": token
        }).eq("Req_id", gatepass_id).execute()

        if res.data:
            return {"status": "success", "message": "Leave Request Approved", "qr_token": token}
        else:
            raise HTTPException(status_code=404, detail="Request not found or update failed")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/reject/{gatepass_id}")
def reject(gatepass_id: int, current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        res = sb.table("Leave_request").update({
            "Status": "Rejected"
        }).eq("Req_id", gatepass_id).execute()

        if res.data:
            return {"status": "success", "message": "Leave Request Rejected"}
        else:
            raise HTTPException(status_code=404, detail="Request not found or update failed")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/stats")
def get_stats(current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()

        # NOTE: created_at column is stored as TIME (no date) in Supabase, so we
        # use leave_date (a proper DATE column, e.g. '2026-04-27') for "today" filtering.
        IST = pytz.timezone("Asia/Kolkata")
        today_str = datetime.now(IST).strftime('%Y-%m-%d')  # e.g. '2026-04-27'

        # Approved today: filter by leave_date == today
        app_res = sb.table("Leave_request").select("Req_id", count='exact') \
            .in_("Status", ["Approved", "Warden_Approved", "Completed", "Exit"]) \
            .eq("leave_date", today_str).execute()

        # Rejected today: filter by leave_date == today
        rej_res = sb.table("Leave_request").select("Req_id", count='exact') \
            .eq("Status", "Rejected") \
            .eq("leave_date", today_str).execute()

        # Active passes = Approved/Exit/Emergency/Warden_Approved (no date filter — any active pass)
        act_res = sb.table("Leave_request").select("Req_id", count='exact') \
            .in_("Status", ["Approved", "Exit", "Emergency", "Warden_Approved"]).execute()

        # Pending review = Parent_Approved awaiting warden action
        pend_res = sb.table("Leave_request").select("Req_id", count='exact') \
            .eq("Status", "Parent_Approved").execute()

        # Emergency passes count
        emg_res = sb.table("Leave_request").select("Req_id", count='exact') \
            .eq("Status", "Emergency").execute()

        # Occupancy: students currently outside (Exit status)
        outside_res = sb.table("Leave_request").select("Req_id", count='exact') \
            .eq("Status", "Exit").execute()
        total_students_res = sb.table("Student").select("AU_id", count='exact').execute()

        total_students = total_students_res.count if total_students_res.count is not None else 0
        outside_campus = outside_res.count if outside_res.count is not None else 0
        inside_campus = total_students - outside_campus

        print(f"[stats] today={today_str}, approved={app_res.count}, rejected={rej_res.count}, active={act_res.count}")

        return {
            "status": "success",
            "approved_today": app_res.count if app_res.count is not None else 0,
            "rejected_today": rej_res.count if rej_res.count is not None else 0,
            "active_passes": act_res.count if act_res.count is not None else 0,
            "emergency_passes": emg_res.count if emg_res.count is not None else 0,
            "pending_review": pend_res.count if pend_res.count is not None else 0,
            "total_students": total_students,
            "outside_campus": outside_campus,
            "inside_campus": inside_campus
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/rejected-list")
def get_rejected_list(current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        # NOTE: created_at has no date part; use leave_date (proper DATE column) for today filter
        IST = pytz.timezone("Asia/Kolkata")
        today_str = datetime.now(IST).strftime('%Y-%m-%d')

        res = sb.table("Leave_request") \
            .select("Req_id, AU_id, Destination, Reason, leave_date") \
            .eq("Status", "Rejected") \
            .eq("leave_date", today_str) \
            .order("leave_date", desc=True).limit(20).execute()
        
        data = res.data
        for req in data:
            s_res = sb.table("Student").select("Name").eq("AU_id", req.get("AU_id")).execute()
            req["student_name"] = s_res.data[0].get("Name") if s_res.data else "Unknown"
            
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/history")
def get_history(date: Optional[str] = Query(None), current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        IST = pytz.timezone("Asia/Kolkata")
        
        if not date:
            date = datetime.now(IST).strftime('%Y-%m-%d')

        # Convert the given IST date to UTC range for Supabase query
        date_ist = IST.localize(datetime.strptime(date, '%Y-%m-%d'))
        date_utc_start = date_ist.astimezone(pytz.utc).isoformat()
        date_utc_end = (date_ist + timedelta(days=1)).astimezone(pytz.utc).isoformat()
        
        res = sb.table("Leave_request").select("Req_id, AU_id, Destination, Status, created_at").gte("created_at", date_utc_start).lt("created_at", date_utc_end).execute()
        
        data = res.data
        for req in data:
            s_res = sb.table("Student").select("Name").eq("AU_id", req.get("AU_id")).execute()
            req["student_name"] = s_res.data[0].get("Name") if s_res.data else "Unknown"
            
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/reset-device/{student_uid}")
def reset_device(student_uid: str, current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        sb.table("Student").update({"device_id": None}).eq("AU_id", student_uid).execute()
        return {"status": "success", "message": f"Device locks cleared for UID {student_uid}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/emergency-pass")
def emergency_pass(data: EmergencyPassRequest, current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        student_res = sb.table("Student").select("Name").eq("AU_id", data.student_id).execute()
        if not student_res.data:
            raise HTTPException(status_code=404, detail="Student UID not found")
            
        token, _ = generate_qr()
        
        # Clean UID if it's a string like "W-01"
        w_id = current_user.get("user_id")
        try:
            w_id = int(str(w_id).split("-")[-1]) if "-" in str(w_id) else int(w_id)
        except: pass

        insert_data = {
            "AU_id": data.student_id,
            "Destination": data.destination,
            "Reason": data.reason,
            "Days": 1,
            "Status": "Approved",
            "leave_date": datetime.now().strftime('%Y-%m-%d'),
            "qr_token": token,
            "Warden_id": w_id
        }
        
        try:
            insert_data["type"] = "Emergency"
            res = sb.table("Leave_request").insert(insert_data).execute()
        except Exception:
            if "type" in insert_data: del insert_data["type"]
            res = sb.table("Leave_request").insert(insert_data).execute()

        if res.data:
            return {"status": "success", "message": "Emergency pass created instantly", "qr_token": token}
        raise HTTPException(status_code=500, detail="Failed to create pass")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/update-parent/{student_uid}")
def update_parent(student_uid: str, data: UpdateParentRequest, current_user: dict = Depends(get_current_user)):
    try:
        sb = get_db()
        s_res = sb.table("Student").select("Parent_id").eq("AU_id", student_uid).execute()
        if not s_res.data or not s_res.data[0].get("Parent_id"):
            raise HTTPException(status_code=404, detail="No parent linked to this student")
            
        parent_id = s_res.data[0].get("Parent_id")

        update_data = {}
        if data.father_name: update_data["Father_Name"] = data.father_name
        if data.mother_name: update_data["Mother_Name"] = data.mother_name
        if data.father_phone: update_data["Father_Phone"] = data.father_phone
        if data.mother_phone: update_data["Mother_Phone"] = data.mother_phone
        if data.guardian_phone: update_data["Guardian_Phone"] = data.guardian_phone
        if data.address: update_data["Address"] = data.address

        if not update_data:
            raise HTTPException(status_code=400, detail="No data provided to update")

        p_res = sb.table("Parent").update(update_data).eq("Parent_id", parent_id).execute()

        if p_res.data:
            return {"status": "success", "message": "Multi-guardian details updated successfully"}
        raise HTTPException(status_code=404, detail="No matching parent record found")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/search")
def search_student(query: str = Query(""), current_user: dict = Depends(get_current_user)):
    try:
        query = query.strip()
        if not query:
            return []

        sb = get_db()
        
        # Build a safe query: Name is always a string, but AU_id and Room_no might be numeric in some DB schemas
        # ilike is safe for strings.
        if query.isdigit():
             s_res = sb.table("Student").select("AU_id, Name, Room_no, Parent_id, Student_image, Department, Course").or_(f"Name.ilike.%{query}%,AU_id.eq.{query},Room_no.eq.{query}").execute()
        else:
             s_res = sb.table("Student").select("AU_id, Name, Room_no, Parent_id, Student_image, Department, Course").ilike("Name", f"%{query}%").execute()
        
        results = s_res.data
        for s in results:
            p_id = s.get("Parent_id")
            if p_id:
                try:
                    p_res = sb.table("Parent").select("Father_Name, Father_Phone, Mother_Name, Mother_Phone, Guardian_Phone, Address").eq("Parent_id", p_id).execute()
                    s["parent_info"] = p_res.data[0] if p_res.data else None
                except Exception:
                    try:
                        p_res = sb.table("Parent").select("Name, Phone, Relation, Address").eq("Parent_id", p_id).execute()
                        s["parent_info"] = p_res.data[0] if p_res.data else None
                    except Exception:
                        s["parent_info"] = None
            
            s["profile_url"] = s.get("Student_image")
            
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/activity")
def get_activity(date: Optional[str] = Query(None), current_user: dict = Depends(get_current_user)):
    """Return approved + rejected leave requests for a given date (defaults to today IST).
    Useful for the warden to see what happened on any given day."""
    try:
        sb = get_db()
        IST = pytz.timezone("Asia/Kolkata")

        if not date:
            date = datetime.now(IST).strftime('%Y-%m-%d')

        # Query by leave_date (a proper DATE column stored as IST date string)
        res = sb.table("Leave_request") \
            .select("Req_id, AU_id, Destination, Reason, Days, Status, leave_date, created_at") \
            .in_("Status", ["Approved", "Warden_Approved", "Completed", "Exit", "Rejected"]) \
            .eq("leave_date", date) \
            .order("created_at", desc=True) \
            .execute()

        data = res.data or []
        result = []
        for req in data:
            s_res = sb.table("Student").select("Name, Student_image, AU_id, Department, Gender").eq("AU_id", req.get("AU_id")).execute()
            student = s_res.data[0] if s_res.data else {}
            req["student_name"] = student.get("Name") or "Unknown"
            req["profile_url"] = student.get("Student_image") or f"https://ui-avatars.com/api/?name={student.get('Name', 'S')}&background=2D5AF0&color=fff"
            req["Department"] = student.get("Department") or ""
            req["Gender"] = student.get("Gender") or ""
            result.append(req)

        print(f"✅ /warden/activity → {len(result)} records for date={date}")
        return result
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/gate-logs")
def get_gate_logs(
    date: Optional[str] = Query(None),
    gender: Optional[str] = Query(None),
    dept: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user)
):
    try:
        sb = get_db()
        IST = pytz.timezone("Asia/Kolkata")
        query = sb.table("Gate_log").select("*, Student:stu_id(AU_id, Name, Student_image, Room_no, Department, Gender)")

        if date:
            # Convert IST date to UTC range for Supabase (timestamps stored in UTC)
            date_ist = IST.localize(datetime.strptime(date, '%Y-%m-%d'))
            date_utc_start = date_ist.astimezone(pytz.utc).isoformat()
            date_utc_end = (date_ist + timedelta(days=1)).astimezone(pytz.utc).isoformat()
            query = query.gte("Timestamp", date_utc_start).lt("Timestamp", date_utc_end)
        else:
            # Default: today in IST → UTC
            today_ist = datetime.now(IST).replace(hour=0, minute=0, second=0, microsecond=0)
            today_utc_start = today_ist.astimezone(pytz.utc).isoformat()
            tomorrow_utc_start = (today_ist + timedelta(days=1)).astimezone(pytz.utc).isoformat()
            query = query.gte("Timestamp", today_utc_start).lt("Timestamp", tomorrow_utc_start)

        res = query.order("Timestamp", desc=True).execute()
        data = res.data or []

        filtered_data = []
        for log in data:
            student = log.get("Student") or {}
            if gender and gender != "All" and student.get("Gender") != gender:
                continue
            if dept and dept != "All" and student.get("Department") != dept:
                continue
            filtered_data.append(log)

        print(f"✅ /warden/gate-logs → {len(filtered_data)} records for date={date}")
        return filtered_data
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"Gate logs error: {e}")
        raise HTTPException(status_code=500, detail=str(e))