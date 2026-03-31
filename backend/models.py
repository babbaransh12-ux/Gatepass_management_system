from pydantic import BaseModel
from typing import Optional

class LoginRequest(BaseModel):
    uid: str
    password: str
    role: str = "Student"
    device_id: Optional[str] = None

class GatepassRequest(BaseModel):
    student_id: str
    destination: str
    reason: str
    duration: str = "24"
    leave_date: Optional[str] = None
    contact: Optional[str] = "father"
    language: Optional[str] = "en"

class WardenActionRequest(BaseModel):
    req_id: int
    status: str
    reason: Optional[str] = None

class EmergencyPassRequest(BaseModel):
    student_id: str
    destination: Optional[str] = "Emergency Default"
    reason: Optional[str] = "Emergency override by Warden"

class UpdateParentRequest(BaseModel):
    father_name: Optional[str] = None
    mother_name: Optional[str] = None
    father_phone: Optional[str] = None
    mother_phone: Optional[str] = None
    guardian_phone: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None # Legacy support
    relation: Optional[str] = None # Legacy support
