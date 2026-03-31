import os
from typing import Optional
from fastapi import APIRouter, Request, Response, Form, Query
from db import get_db
from services.twilio_service import make_call

router = APIRouter(prefix="/ivr", tags=["ivr"])

@router.api_route("/voice/{req_id}", methods=["GET", "POST"])
def voice_call(req_id: int, retry: int = Query(0)):
    """Generate localized TwiML for the parent call."""
    try:
        sb = get_db()
        res = sb.table("Leave_request").select("AU_id, Destination, language").eq("Req_id", req_id).execute()
        if not res.data: 
            print(f"❌ IVR Error: Request {req_id} not found in DB")
            return Response(content="Not Found", status_code=404)
        
        req = res.data[0]
        lang = req.get("language", "hi").lower()
        dest = req.get("Destination", "Outing")
        
        stu_res = sb.table("Student").select("Name").eq("AU_id", req["AU_id"]).execute()
        student_name = stu_res.data[0]["Name"] if stu_res.data else "Student"

        scripts = {
            "en": {
                "voice_lang": "en-IN",
                "voice_name": "Polly.Aditi",
                "msg": f"Hello, this is E-Gate-pass. Permission is needed for student {student_name} to visit {dest}. Press 1 to approve, 2 to reject."
            },
            "hi": {
                "voice_lang": "hi-IN",
                "voice_name": "Polly.Aditi",
                "msg": f"नमस्ते, यह ई-गेट-पास है। छात्र {student_name} को {dest} जाने के लिए अनुमति चाहिए। अनुमति देने के लिए 1 दबाएं, अस्वीकार करने के लिए 2 दबाएं।"
            },
            "pa": {
                "voice_lang": "pa-IN",
                "voice_name": "Google.pa-IN-Standard-A",
                "msg": f"ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ, ਇਹ ਈ-ਗੇਟ-ਾਸ ਹੈ। ਵਿਦਿਆਰਥੀ {student_name} ਲਈ {dest} ਜਾਣ ਦੀ ਆਗਿਆ ਚਾਹੀਦੀ ਹੈ। ਆਗਿਆ ਦੇਣ ਲਈ 1 ਦਬਾਓ, ਅਸਵੀਕਾਰ ਕਰਨ ਲਈ 2 ਦਬਾਓ।"
            }
        }

        config = scripts.get(lang, scripts["hi"])
        base_url = os.getenv("BASE_URL", "").rstrip("/")
        
        twiml = (
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<Response>'
            f'<Gather numDigits="1" action="{base_url}/ivr/handle-response/{req_id}?retry={retry}" method="POST" timeout="10">'
            f'<Say language="{config["voice_lang"]}" voice="{config["voice_name"]}">{config["msg"]} प्रेस 3 दोहराने के लिए। (Press 3 to repeat.)</Say>'
            '</Gather>'
        )
        
        if retry < 2:
            twiml += f'<Redirect method="POST">{base_url}/ivr/voice/{req_id}?retry={retry + 1}</Redirect>'
        else:
            twiml += f'<Say language="{config["voice_lang"]}" voice="{config["voice_name"]}">असुविधा के लिए खेद है। आपका दिन शुभ हो। (Sorry for the inconvenience. Goodbye.)</Say>'
            twiml += '<Hangup/>'
            
        twiml += '</Response>'
        print(f"✅ IVR: TwiML generated for Req {req_id} ({lang}, Retry: {retry})")
        return Response(content=twiml, media_type="text/xml")
        
    except Exception as e:
        print(f"🔥 IVR Crash on Req {req_id}: {e}")
        return Response(content=str(e), status_code=500)

@router.post("/handle-response/{req_id}")
def handle_response(
    req_id: int, 
    Digits: Optional[str] = Form(None), 
    retry: int = Query(0)
):
    """Handle the parent's keypad response (1=Approved, 2=Rejected)."""
    sb = get_db()
    twiml = '<?xml version="1.0" encoding="UTF-8"?><Response>'
    base_url = os.getenv("BASE_URL", "").rstrip("/")
    
    if Digits == "1":
        sb.table("Leave_request").update({"Status": "Parent_Approved"}).eq("Req_id", req_id).execute()
        twiml += '<Say language="hi-IN" voice="Polly.Aditi">धन्यवाद, अनुमति प्रदान की गई है। आपका दिन शुभ हो। (Thank you, permission granted. Have a nice day.)</Say>'
    elif Digits == "2":
        sb.table("Leave_request").update({"Status": "Rejected", "Reason": "Rejected by Parent"}).eq("Req_id", req_id).execute()
        twiml += '<Say language="hi-IN" voice="Polly.Aditi">ठीक है, अनुमति अस्वीकार कर दी गई है। (Okay, permission rejected.)</Say>'
    elif Digits == "3":
        twiml += f'<Redirect method="POST">{base_url}/ivr/voice/{req_id}?retry={retry}</Redirect>'
    else:
        if retry < 2:
            twiml += f'<Say language="hi-IN" voice="Polly.Aditi">गलत प्रविष्टि। (Wrong entry.)</Say>'
            twiml += f'<Redirect method="POST">{base_url}/ivr/voice/{req_id}?retry={retry + 1}</Redirect>'
        else:
            twiml += '<Say language="hi-IN" voice="Polly.Aditi">असुविधा के लिए खेद है। (Sorry for the inconvenience.)</Say>'
            twiml += '<Hangup/>'
        
    twiml += "</Response>"
    return Response(content=twiml, media_type="text/xml")

@router.post("/status/{req_id}")
def call_status(
    req_id: int, 
    CallStatus: Optional[str] = Form(None)
):
    """Handle Twilio call status callbacks and redial/rotate logic."""
    print(f"📡 Twilio Status for Req {req_id}: {CallStatus}")

    if CallStatus == "completed":
        print(f"✅ Call to parent for Req {req_id} was answered.")
        return "OK"

    if CallStatus in ["busy", "no-answer", "failed", "canceled"]:
        sb = get_db()
        res = sb.table("Leave_request").select("attempts, AU_id, Status, current_parent").eq("Req_id", req_id).execute()
        if not res.data:
            return Response(content="Not Found", status_code=404)
            
        req = res.data[0]
        attempts = req.get("attempts", 0) + 1
        current_p = req.get("current_parent", "Father")
        student_id = req["AU_id"]

        if attempts > 3:
            print(f"🚑 Max attempts reached (3/3) for Req {req_id}. Triggering Emergency.")
            sb.table("Leave_request").update({"Status": "Emergency", "attempts": 3, "Reason": "Parent Unavailable after 3 attempts"}).eq("Req_id", req_id).execute()
            return "Emergency Triggered"

        stu_res = sb.table("Student").select("Parent_id").eq("AU_id", student_id).execute()
        if not stu_res.data: return Response(content="Student Not Found", status_code=404)
        
        pid = stu_res.data[0]["Parent_id"]
        parent_res = sb.table("Parent").select("Father_Phone, Mother_Phone, Guardian_Phone").eq("Parent_id", pid).execute()
        if not parent_res.data: return Response(content="Parent Not Found", status_code=404)
        
        p = parent_res.data[0]
        next_phone = None
        next_parent = current_p

        if attempts <= 3:
            print(f"🔄 Redialing {current_p} for Req {req_id} (Attempt {attempts}/3)...")
            next_phone = p.get(f"{current_p}_Phone") or p.get("Phone")
        else:
            if current_p == "Father":
                next_parent = "Mother"
                next_phone = p.get("Mother_Phone")
            elif current_p == "Mother":
                next_parent = "Guardian"
                next_phone = p.get("Guardian_Phone")
            
            if next_phone:
                print(f"🔀 Rotating to {next_parent} for Req {req_id}...")
                attempts = 1
            else:
                print(f"🚑 All guardians unreachable for Req {req_id}. Triggering Emergency.")
                sb.table("Leave_request").update({"Status": "Emergency", "attempts": 3}).eq("Req_id", req_id).execute()
                return "Emergency Triggered"

        sb.table("Leave_request").update({"attempts": attempts, "current_parent": next_parent}).eq("Req_id", req_id).execute()
        if next_phone:
            make_call(next_phone, req_id)

    return "OK"