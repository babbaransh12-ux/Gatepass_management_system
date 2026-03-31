import os, sys, json
sys.path.append('backend')
from dotenv import load_dotenv
load_dotenv('backend/.env')
from backend.db import get_db

sb = get_db()
res = sb.table('Leave_request').select('Req_id, AU_id, Destination, Days, Reason, leave_date, Status').in_('Status', ['Pending', 'Parent_Approved']).execute()

data = res.data
print("Raw count:", len(data))
print(json.dumps(data, indent=2))
