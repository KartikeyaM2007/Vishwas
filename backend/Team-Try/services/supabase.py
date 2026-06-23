# services/supabase.py

from supabase import create_client
from utils.config import SUPABASE_URL, SUPABASE_KEY
import sys

url = SUPABASE_URL
key = SUPABASE_KEY

supabase = None
if url and key:
    if not url.startswith("https://") or ".supabase.co" not in url:
        print(f"ERROR: SUPABASE_URL format invalid. Received: {url}")
    else:
        try:
            supabase = create_client(url, key)
        except Exception as e:
            print(f"ERROR connecting to Supabase: {e}")

def check_supabase_connection():
    if not supabase:
        return False
    try:
        supabase.table("complaints").select("id").limit(1).execute()
        return True
    except Exception as e:
        print(f"Supabase connection test failed: {e}")
        return False

def insert_complaint(data):
    response = supabase.table("complaints").insert(data).execute()
    return response

def run_sql(sql: str):
    # ❗ remove semicolon
    sql = sql.strip().rstrip(";")

    response = supabase.rpc("execute_sql", {"query": sql}).execute()
    
    return response.data[0] if response.data else []