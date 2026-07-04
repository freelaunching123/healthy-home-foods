import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

db_url = os.getenv("SYNC_DATABASE_URL")
if db_url:
    db_url = db_url.replace("db:5432", "localhost:5432")
    
engine = create_engine(db_url)
with engine.connect() as conn:
    res = conn.execute(text("SELECT id, phone, full_name, role, status, is_verified, is_deleted FROM users"))
    print("="*60)
    print("USERS IN DATABASE:")
    print("="*60)
    for row in res:
        print(f"ID: {row[0]} | Phone: {row[1]} | Name: {row[2]} | Role: {row[3]} | Status: {row[4]} | Verified: {row[5]} | Deleted: {row[6]}")
    print("="*60)
