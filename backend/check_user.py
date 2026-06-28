import os
from sqlalchemy import create_engine, text

engine = create_engine(os.environ['SYNC_DATABASE_URL'])
with engine.connect() as conn:
    res = conn.execute(text("SELECT phone, role, password_hash FROM users WHERE phone='9876543210'"))
    for row in res:
        print(row)
