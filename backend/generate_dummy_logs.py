import sys
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv
load_dotenv()
from db import get_db
import datetime
import pytz

sb = get_db()
res = sb.table('Leave_request').select('Req_id, AU_id, Status').order('Req_id', desc=True).limit(5).execute()
requests = res.data
if not requests:
    print('No leave requests found to generate dummy data.')
    sys.exit(0)

IST = pytz.timezone('Asia/Kolkata')
now = datetime.datetime.now(IST)

logs = []
for i, req in enumerate(requests):
    req_id = req['Req_id']
    au_id = req['AU_id']
    
    t_exit = (now - datetime.timedelta(hours=3, minutes=i*15)).astimezone(pytz.utc)
    logs.append({
        'req_id': req_id,
        'stu_id': au_id,
        'Action': 'exit',
        'Timestamp': t_exit.isoformat(),
        'Gaurd_id': 101
    })
    
    if i % 2 == 0:
        t_entry = (now - datetime.timedelta(hours=1, minutes=i*10)).astimezone(pytz.utc)
        logs.append({
            'req_id': req_id,
            'stu_id': au_id,
            'Action': 'entry',
            'Timestamp': t_entry.isoformat(),
            'Gaurd_id': 101
        })

print(f"Inserting {len(logs)} dummy logs into Gate_log...")
for log in logs:
    try:
        sb.table('Gate_log').insert(log).execute()
        print(f"Inserted {log['Action']} for Req_id {log['req_id']}")
    except Exception as e:
        print(f"Failed to insert log for {log['req_id']}: {e}")

print("Done!")
