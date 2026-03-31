import os, sys, json
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.getcwd(), '.env'))
from backend.db import get_db

sb = get_db()
res = sb.table('Leave_request').select('*').execute()

pending = [r for r in res.data if r.get('Status') in ['Pending', 'Parent_Approved']]

with open('debug.json', 'w') as f:
    f.write(json.dumps(pending, indent=2))
