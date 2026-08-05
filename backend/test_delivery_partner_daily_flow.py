import asyncio
import uuid
from datetime import date, datetime, timezone, timedelta
import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.models.user import User, UserRoleEnum
from app.models.customer import Customer
from app.models.product import Product, ProductCategory
from app.models.address import Address
from app.models.subscription import Subscription, SubscriptionStatus
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.delivery_partner import DeliveryPartner
from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
from app.services import subscription_engine
from app.main import app
from app.db.base import Base

DATABASE_URL = getattr(settings, "DATABASE_URL", "sqlite+aiosqlite:///healthyhomefoods.db")
engine = create_async_engine(DATABASE_URL, echo=False)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def test_delivery_partner_daily_flow():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as session:
        # Create test customer user
        test_uid = uuid.uuid4()
        cust_user = User(
            id=test_uid,
            email=f"dp_cust_{test_uid.hex[:6]}@example.com",
            phone=f"98{uuid.uuid4().int % 100000000:08d}",
            full_name="Delivery Flow Customer",
            role=UserRoleEnum.CUSTOMER
        )
        session.add(cust_user)
        await session.flush()

        cust = Customer(id=uuid.uuid4(), user_id=cust_user.id, customer_code=f"CUST-{test_uid.hex[:6]}")
        session.add(cust)
        await session.flush()

        addr = Address(
            id=uuid.uuid4(),
            user_id=cust_user.id,
            label="Home",
            recipient_name="Delivery Flow Customer",
            recipient_phone="9888888888",
            address_line1="456 Green St",
            city="Madurai",
            state="Tamil Nadu",
            pincode="625002",
            latitude=9.919630,
            longitude=78.094379,
            is_default=True
        )
        session.add(addr)

        # Create delivery partner user
        dp_uid = uuid.uuid4()
        dp_user = User(
            id=dp_uid,
            email=f"dp_boy_{dp_uid.hex[:6]}@example.com",
            phone=f"97{uuid.uuid4().int % 100000000:08d}",
            full_name="Rajesh Delivery Boy",
            role=UserRoleEnum.DELIVERY_PARTNER
        )
        session.add(dp_user)
        await session.flush()

        dp = DeliveryPartner(
            id=uuid.uuid4(),
            user_id=dp_user.id,
            employee_code=f"EMP-{dp_uid.hex[:4].upper()}"
        )
        session.add(dp)

        # Create Product
        cat = ProductCategory(id=uuid.uuid4(), name="Daily Meal Category", slug=f"daily-meal-{uuid.uuid4().hex[:6]}")
        session.add(cat)
        await session.flush()

        prod = Product(
            id=uuid.uuid4(),
            category_id=cat.id,
            name="Daily Meal Package (6 Days)",
            slug=f"daily-meal-{uuid.uuid4().hex[:6]}",
            plan_type="weekly",
            package_days=6,
            package_price=1200.0,
            is_active=True
        )
        session.add(prod)
        await session.flush()

        # Create Subscription assigned to DP
        sub = Subscription(
            id=uuid.uuid4(),
            customer_id=cust.id,
            product_id=prod.id,
            address_id=addr.id,
            delivery_partner_id=dp.id,
            status=SubscriptionStatus.ACTIVE,
            start_date=date.today(),
            plan_type="weekly",
            total_deliveries=6,
            completed_deliveries=0,
            package_price=1200.0,
            total_amount=1200.0
        )
        session.add(sub)
        await session.flush()

        # Generate today's initial delivery
        deliv_today = await subscription_engine._generate_next_delivery(session, sub)
        await session.commit()

        # Create authorization token for DP
        from app.core.security import create_access_token
        dp_token = create_access_token(data={"sub": str(dp_user.id), "role": dp_user.role.value})
        headers = {"Authorization": f"Bearer {dp_token}"}

        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
            print("\n--- 1. Testing GET /api/v1/delivery-partner/active for TODAY ---")
            res_active1 = await client.get("/api/v1/delivery-partner/active", headers=headers)
            print(f"Status: {res_active1.status_code}")
            assert res_active1.status_code == 200
            active_list1 = res_active1.json()
            print(f"Found {len(active_list1)} active delivery for today")
            assert len(active_list1) == 1, "Should have exactly 1 active delivery for today"
            assignment_id = active_list1[0]["id"]

            print("\n--- 2. Delivery Boy Marks Delivery as DELIVERED ---")
            res_status = await client.put(
                f"/api/v1/delivery-partner/assignments/{assignment_id}/status",
                json={"status": "delivered"},
                headers=headers
            )
            print(f"Update Status: {res_status.status_code}, Response: {res_status.json()}")
            assert res_status.status_code == 200

            print("\n--- 3. Testing GET /api/v1/delivery-partner/active AGAIN on same day ---")
            res_active2 = await client.get("/api/v1/delivery-partner/active", headers=headers)
            print(f"Status: {res_active2.status_code}")
            assert res_active2.status_code == 200
            active_list2 = res_active2.json()
            print(f"Found {len(active_list2)} active deliveries on same day after completing today's delivery")
            assert len(active_list2) == 0, f"Expected 0 active deliveries for today, but got {len(active_list2)}! Tomorrow's delivery must not show up today."

            print("\n==============================================")
            print("DELIVERY PARTNER DAILY FLOW TEST PASSED SUCCESSFULLY!")
            print("==============================================")

if __name__ == "__main__":
    asyncio.run(test_delivery_partner_daily_flow())
