import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from app.core.config import settings

async def test_db():
    try:
        engine = create_async_engine(settings.DATABASE_URL)
        async with engine.begin() as conn:
            print("Connected to DB successfully!")
    except Exception as e:
        print("DB Connection Failed:", type(e).__name__, str(e))

asyncio.run(test_db())
