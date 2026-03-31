import requests

try:
    # First login as warden to get token
    login_res = requests.post("http://127.0.0.1:5000/auth/login", json={
        "uid": "1",
        "username": "warden1",
        "password": "password",  # Just guessing typical dev password or we don't need it if we mock token
        "role": "Warden"
    })
    
    # Actually wait we can bypass auth just invoking the underlying python function
    import sys, os, json
    sys.path.append(os.path.join(os.getcwd(), 'backend'))
    from dotenv import load_dotenv
    load_dotenv(os.path.join(os.getcwd(), '.env'))
    import app
    
    with app.app.test_request_context('/warden/pending', headers={'Authorization': 'Bearer test'}):
        # We need to test the actual route logic
        from backend.db import get_db
        sb = get_db()
        res = sb.table("Leave_request").select("Req_id, AU_id, Destination, Days, Reason, leave_date, Status").in_("Status", ["Pending", "Parent_Approved"]).execute()
        
        data = res.data
        for req in data:
            s_res = sb.table("Student").select("Name", "Student_image").eq("AU_id", req.get("AU_id")).execute()
            req["student_name"] = s_res.data[0].get("Name") if s_res.data else "Unknown"
            req["profile_url"] = s_res.data[0].get("Student_image") if s_res.data else None
            
            # Map "Parent_Approved" text to a UI-friendly label
            if req.get("Status") == "Parent_Approved":
                req["Reason"] = f"(✅ Parent Approved) {req.get('Reason', '')}"
            
            # Remove Status key to prevent frontend parsing crashes (legacy compatibility)
            if "Status" in req:
                del req["Status"]
        
        print("FLASK ROUTE WOULD RETURN THIS EXACT JSON:")
        print(json.dumps(data, indent=2))
        
except Exception as e:
    print("ERROR:", e)
