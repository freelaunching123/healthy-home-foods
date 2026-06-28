import os
from sqlalchemy import create_engine, text
from app.core.security import hash_password

engine = create_engine(os.environ['SYNC_DATABASE_URL'])
with engine.connect() as conn:
    new_hash = hash_password('Admin123')
    conn.execute(text("UPDATE users SET password_hash=:hash WHERE phone='9876543210'"), {"hash": new_hash})
    conn.commit()
    print('Password hash manually reset to Admin123')
