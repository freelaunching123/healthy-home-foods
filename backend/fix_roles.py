import asyncio
import os
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text
from dotenv import load_dotenv

load_dotenv()

async def fix_roles():
    db_url = os.getenv("DATABASE_URL")
    if db_url:
        db_url = db_url.replace("db:5432", "localhost:5432") # Assuming exposed on localhost
    engine = create_async_engine(db_url)
    async_session = sessionmaker(engine, class_=AsyncSession)
    
    async with async_session() as session:
        try:
            # Update all users that have a delivery partner profile to have the correct role
            query = text("""
                UPDATE users 
                SET role = 'delivery_partner'
                WHERE id IN (
                    SELECT user_id FROM delivery_partners
                ) AND role != 'delivery_partner'
            """)
            result = await session.execute(query)
            await session.commit()
            print(f"Updated {result.rowcount} users to delivery_partner role.")
        except Exception as e:
            print(f"Error: {e}")

asyncio.run(fix_roles())
