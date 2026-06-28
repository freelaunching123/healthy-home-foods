import os
from sqlalchemy import create_engine, text

engine = create_engine(os.environ['SYNC_DATABASE_URL'])
with engine.connect() as conn:
    # update dummy customer to random number if exists
    conn.execute(text("UPDATE users SET phone='9876543211' WHERE phone='9876543210' AND role='customer'"))
    # update admin to new number
    conn.execute(text("UPDATE users SET phone='9876543210' WHERE phone='9999999999' AND role IN ('admin', 'super_admin')"))
    conn.commit()
    print('Updated admin phone number in database.')
