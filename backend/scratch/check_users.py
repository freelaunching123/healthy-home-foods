import asyncio
import os
import sys
from sqlalchemy import select

# Set PYTHONPATH and DB URL
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ["DATABASE_URL"] = "postgresql+asyncpg://hhf_user:hhf_password@localhost:5432/healthy_home_foods"

from app.db.session import AsyncSessionLocal
from app.db.models_import import *
from app.models.user import User

from app.core.security import hash_password

async def run():
    async with AsyncSessionLocal() as s:
        new_hash = hash_password("password123")
        # Update delivery partner 9876598764
        await s.execute(
            text("UPDATE users SET password_hash=:hash WHERE phone='9876598764'"),
            {"hash": new_hash}
        )
        # Update customer 9876543213
        await s.execute(
            text("UPDATE users SET password_hash=:hash WHERE phone='9876543213'"),
            {"hash": new_hash}
        )
        await s.commit()
        print("Successfully updated database credentials to password123!")

if __name__ == "__main__":
    from sqlalchemy import text
    asyncio.run(run())
