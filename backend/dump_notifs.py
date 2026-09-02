import asyncio
from app.db.session import AsyncSessionLocal
from app.models.notification import Notification
from sqlalchemy import select

async def main():
    async with AsyncSessionLocal() as session:
        res = await session.execute(select(Notification).order_by(Notification.created_at.desc()).limit(10))
        for n in res.scalars().all():
            print(f"Title: {n.title}, Category: {n.category}, ActionType: {n.action_type}")

asyncio.run(main())
