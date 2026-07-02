import asyncio
import logging
import shortuuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import AsyncSessionLocal
from app.models.user import User, UserStatus, UserRoleEnum
from app.models.customer import Customer
from app.models.delivery_partner import DeliveryPartner
from app.db.models_import import *
from app.core.security import hash_password

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def seed_roles():
    async with AsyncSessionLocal() as db:
        # Seed Customer
        cust_phone = "1111111111"
        cust_result = await db.execute(select(User).where(User.phone == cust_phone))
        customer_user = cust_result.scalar_one_or_none()
        
        if not customer_user:
            customer_user = User(
                phone=cust_phone,
                email="customer@example.com",
                full_name="Test Customer",
                password_hash=hash_password("Customer123"),
                is_verified=True,
                status=UserStatus.ACTIVE,
                role=UserRoleEnum.CUSTOMER,
            )
            db.add(customer_user)
            await db.flush()
            
            customer_code = f"C{shortuuid.ShortUUID().random(length=8).upper()}"
            db.add(Customer(user_id=customer_user.id, customer_code=customer_code))
            logger.info("Seeded Test Customer")

        # Seed Delivery Partner
        dp_phone = "2222222222"
        dp_result = await db.execute(select(User).where(User.phone == dp_phone))
        dp_user = dp_result.scalar_one_or_none()
        
        if not dp_user:
            dp_user = User(
                phone=dp_phone,
                email="delivery@example.com",
                full_name="Test Delivery",
                password_hash=hash_password("Delivery123"),
                is_verified=True,
                status=UserStatus.ACTIVE,
                role=UserRoleEnum.DELIVERY_PARTNER,
            )
            db.add(dp_user)
            await db.flush()
            
            dp_code = f"DP{shortuuid.ShortUUID().random(length=6).upper()}"
            db.add(DeliveryPartner(user_id=dp_user.id, employee_code=dp_code, is_available=True))
            logger.info("Seeded Test Delivery Partner")

        await db.commit()
        logger.info("✅ Roles seeding complete!")

if __name__ == "__main__":
    asyncio.run(seed_roles())
