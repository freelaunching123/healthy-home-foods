import asyncio
import sys
import os

sys.path.insert(0, r"e:\healthy-home-foods-main\backend")

from sqlalchemy import select
from app.db.session import async_session_maker
from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.subscription import Subscription
from app.models.user import User

async def main():
    async with async_session_maker() as db:
        # Just grab any assignment that is NOT delivered or failed
        query = select(DeliveryAssignment).where(
            DeliveryAssignment.status.in_([AssignmentStatus.PENDING, AssignmentStatus.ACCEPTED, AssignmentStatus.OUT_FOR_DELIVERY])
        )
        result = await db.execute(query)
        assignments = result.scalars().all()
        
        print(f"Total active assignments: {len(assignments)}")
        
        for a in assignments:
            if a.subscription_delivery_id:
                sd_res = await db.execute(select(SubscriptionDelivery).where(SubscriptionDelivery.id == a.subscription_delivery_id))
                sd = sd_res.scalar_one_or_none()
                if not sd:
                    continue
                
                sub_res = await db.execute(select(Subscription).where(Subscription.id == sd.subscription_id))
                sub = sub_res.scalar_one_or_none()
                
                sub_status_str = sub.status.value if hasattr(sub.status, "value") else str(sub.status)
                print(f"Assignment {a.id} -> Sub Delivery {sd.id} (Status: {sd.status}) -> Sub {sub.id} (Status: {sub_status_str})")
                
                will_skip_sd = sd.status in [DeliveryStatus.DELIVERED, DeliveryStatus.SKIPPED]
                will_skip_sub = sub_status_str.lower() in ["paused", "cancelled"]
                print(f"  Will skip? SD: {will_skip_sd}, SUB: {will_skip_sub}")

if __name__ == "__main__":
    asyncio.run(main())
