"""Check which delivery model attributes exist"""
import asyncio
import app.db.models_import
from app.db.session import AsyncSessionLocal
from app.models.delivery_partner import DeliveryPartner
from app.models.delivery import DeliveryAssignment
from app.models.user import User, UserStatus
from sqlalchemy import select, func, or_

async def test():
    async with AsyncSessionLocal() as db:
        try:
            query = (
                select(User, DeliveryPartner)
                .join(DeliveryPartner, DeliveryPartner.user_id == User.id)
            )
            result = await db.execute(query)
            rows = result.all()
            print(f"Found {len(rows)} delivery partners")
            
            for user, dp in rows:
                # Test DeliveryAssignment count
                assign_result = await db.execute(
                    select(func.count()).where(DeliveryAssignment.delivery_partner_id == dp.id)
                )
                count = assign_result.scalar_one()
                print(f"  {user.full_name}: status={user.status}, is_active={user.status == UserStatus.active}, assigned={count}")
        except Exception as e:
            import traceback
            traceback.print_exc()

asyncio.run(test())
