import os
import json
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

def check_schema():
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_ANON_KEY")
    supabase: Client = create_client(url, key)
    
    tables = ["Student", "Parent", "User", "Leave_request"]
    schema = {}
    
    for table in tables:
        try:
            res = supabase.table(table).select("*").limit(1).execute()
            if res.data:
                schema[table] = list(res.data[0].keys())
            else:
                schema[table] = "No data"
        except Exception as e:
            schema[table] = f"Error: {str(e)}"
            
    with open("schema_dump.json", "w") as f:
        json.dump(schema, f, indent=4)

if __name__ == "__main__":
    check_schema()
