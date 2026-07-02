import os
from sqlalchemy import create_engine, text

engine = create_engine(os.environ['SYNC_DATABASE_URL'])
with engine.connect() as conn:
    res = conn.execute(text("SELECT id, name, created_at FROM products ORDER BY created_at DESC LIMIT 5"))
    for row in res:
        print(row)
