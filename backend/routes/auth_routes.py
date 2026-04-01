import os
import jwt
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from db import get_db

router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer()

# Load Secret Key from .env
SECRET_KEY = os.getenv("JWT_SECRET", "9f7a7836d0e9458296a2b8e39f7a7836")

class LoginRequest(BaseModel):
    uid: str
    password: str
    role: str = "Student"
    device_id: Optional[str] = None

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        data = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        return data  # Returns dict with user_id, role, gender, etc.
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )

@router.post("/login")
def login(data: LoginRequest):
    try:
        uid = data.uid
        password = data.password
        role = data.role
        device_id = data.device_id
        
        sb = get_db()
        
        # 1. WARDEN LOGIN
        if role == "Warden":
            if password != "warden123":
                raise HTTPException(status_code=401, detail="Invalid password")
            
            # Clean UID if it's a string like "W-01"
            clean_uid = uid
            if isinstance(uid, str) and "-" in uid:
                try:
                    clean_uid = int(uid.split("-")[-1])
                except: pass

            try:
                w_res = sb.table("Warden").select("Gender").eq("warden_id", clean_uid).execute()
                gender = w_res.data[0].get("Gender", "Male") if w_res.data else "Male"
            except Exception as e:
                print(f"Warning: Warden Gender column error: {e}")
                gender = "Male"

            token = jwt.encode({
                "user_id": clean_uid, 
                "role": role, 
                "gender": gender,
                "exp": datetime.utcnow() + timedelta(days=7)
            }, SECRET_KEY, algorithm="HS256")
            return {"status": "success", "token": token, "role": role}
            
        # 2. SECURITY LOGIN
        elif role == "Security":
            if password != "security123":
                raise HTTPException(status_code=401, detail="Invalid password")
            token = jwt.encode({
                "user_id": uid, 
                "role": role, 
                "exp": datetime.utcnow() + timedelta(days=7)
            }, SECRET_KEY, algorithm="HS256")
            return {"status": "success", "token": token, "role": role}

        # 3. STUDENT LOGIN
        elif role == "Student":
            res = sb.table("Student").select("Name, Room_no, Parent_id").eq("AU_id", uid).execute()
            if not res.data:
                raise HTTPException(status_code=404, detail="Student UID not found")
            
            student_data = res.data[0]
            parent_id = student_data.get("Parent_id")
            
            if not parent_id:
                raise HTTPException(status_code=404, detail="Parent mapping not found")
                
            parent_res = sb.table("Parent").select("Father_Phone").eq("Parent_id", parent_id).execute()
            if not parent_res.data:
                raise HTTPException(status_code=404, detail="Parent record not found")
                
            correct_password = parent_res.data[0].get("Father_Phone")
            if password != correct_password:
                raise HTTPException(status_code=401, detail="Invalid password (Incorrect Father's Phone Number)")
                
            # DEVICE BINDING
            try:
                dev_res = sb.table("Student").select("device_id").eq("AU_id", uid).execute()
                saved_device = dev_res.data[0].get("device_id")
                
                if not saved_device:
                    if device_id:
                        sb.table("Student").update({"device_id": device_id}).eq("AU_id", uid).execute()
                elif saved_device != device_id:
                    raise HTTPException(status_code=403, detail="Access Denied: Unrecognized Device. Contact Warden.")
            except HTTPException:
                raise
            except Exception as e:
                print(f"Device verification bypassed: {e}")
                
            token = jwt.encode({
                "user_id": uid, 
                "role": role, 
                "exp": datetime.utcnow() + timedelta(days=7)
            }, SECRET_KEY, algorithm="HS256")
            return {"status": "success", "token": token, "role": role}

        raise HTTPException(status_code=400, detail="Invalid role")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
