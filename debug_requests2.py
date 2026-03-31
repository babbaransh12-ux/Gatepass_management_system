import os, sys, json
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.getcwd(), '.env'))
from backend.db import get_db

sb = get_db()
res = sb.table('Leave_request').select('Status, Req_id, AU_id').in_('Status', ['Pending', 'Parent_Approved']).execute()

with open('debug_requests.json', 'w') as f:
    json.dump(res.data, f, indent=2)
