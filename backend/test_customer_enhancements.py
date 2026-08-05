import asyncio
import uuid
from datetime import datetime, timezone
import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.models.user import User, UserRoleEnum
from app.models.customer import Customer
from app.models.product import Product, ProductCategory
from app.models.package_cart import PackageCart
from app.models.address import Address
from app.models.fruit import FruitOrder, FruitPaymentStatus, FruitOrderStatus
from app.models.subscription import Subscription, SubscriptionStatus, SubscriptionPlan
from app.models.payment import Payment, PaymentStatus, PaymentMethod
from app.main import app

from app.db.base import Base

# Setup test DB session
DATABASE_URL = getattr(settings, "DATABASE_URL", "sqlite+aiosqlite:///healthyhomefoods.db")
engine = create_async_engine(DATABASE_URL, echo=False)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def test_customer_features():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as session:
        # Create test customer user
        test_uid = uuid.uuid4()
        test_email = f"testcust_{test_uid.hex[:6]}@example.com"
        cust_user = User(
            id=test_uid,
            email=test_email,
            phone=f"99{uuid.uuid4().int % 100000000:08d}",
            full_name="Test Customer",
            role=UserRoleEnum.CUSTOMER
        )
        session.add(cust_user)
        await session.flush()

        cust_id = uuid.uuid4()
        cust = Customer(id=cust_id, user_id=cust_user.id, customer_code=f"CUST-{test_uid.hex[:6]}")
        session.add(cust)
        await session.flush()

        # Create address
        addr = Address(
            id=uuid.uuid4(),
            user_id=cust_user.id,
            label="Home",
            recipient_name="Test Customer",
            recipient_phone="9999999999",
            address_line1="123 Test St",
            city="Madurai",
            state="Tamil Nadu",
            pincode="625001",
            latitude=9.919630,
            longitude=78.094379,
            is_default=True
        )
        session.add(addr)

        # Create 2 test products (6-day & 26-day)
        cat = ProductCategory(id=uuid.uuid4(), name="Healthy Category", slug=f"healthy-cat-{uuid.uuid4().hex[:6]}")
        session.add(cat)
        await session.flush()

        prod1 = Product(
            id=uuid.uuid4(),
            category_id=cat.id,
            name="Basic Millet Pack (6 Days)",
            slug=f"basic-millet-{uuid.uuid4().hex[:6]}",
            plan_type="weekly",
            package_days=6,
            package_price=1200.0,
            is_active=True
        )
        prod2 = Product(
            id=uuid.uuid4(),
            category_id=cat.id,
            name="Protein Bowl Pack (26 Days)",
            slug=f"protein-bowl-{uuid.uuid4().hex[:6]}",
            plan_type="monthly",
            package_days=26,
            package_price=4500.0,
            is_active=True
        )
        session.add_all([prod1, prod2])
        await session.flush()

        # Create test fruit order
        fruit_order = FruitOrder(
            id=uuid.uuid4(),
            customer_id=cust.id,
            order_number=f"FO-{uuid.uuid4().hex[:6].upper()}",
            total_amount=350.0,
            payment_status=FruitPaymentStatus.SUCCESS,
            order_status=FruitOrderStatus.PENDING,
            paid_at=datetime.now(timezone.utc)
        )
        session.add(fruit_order)
        await session.flush()

        # Create test subscription payment
        sub1 = Subscription(
            id=uuid.uuid4(),
            customer_id=cust.id,
            product_id=prod1.id,
            address_id=addr.id,
            status=SubscriptionStatus.ACTIVE,
            plan_type="weekly",
            total_deliveries=6,
            total_amount=1200.0,
            package_price=1200.0
        )
        session.add(sub1)
        await session.flush()

        pmt = Payment(
            id=uuid.uuid4(),
            customer_id=cust.id,
            subscription_id=sub1.id,
            amount=1200.0,
            status=PaymentStatus.SUCCESS,
            payment_method=PaymentMethod.MOCK_PAYMENT,
            paid_at=datetime.now(timezone.utc)
        )
        session.add(pmt)
        await session.commit()

        # Token for authorization
        from app.core.security import create_access_token
        token = create_access_token(data={"sub": str(cust_user.id), "role": cust_user.role.value})
        headers = {"Authorization": f"Bearer {token}"}

        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
            print("\n--- 1. Testing GET /api/v1/payments/history ---")
            res = await client.get("/api/v1/payments/history", headers=headers)
            print(f"Status: {res.status_code}")
            assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
            data = res.json()
            print(f"Retrieved {len(data)} payment history records")
            assert len(data) >= 2, "Should contain both Subscription Payment and Fruit Order Payment"
            print("[OK] Payment history test passed!")

            print("\n--- 2. Testing GET /api/v1/payments/{payment_id}/invoice for Subscription Payment ---")
            res_inv1 = await client.get(f"/api/v1/payments/{pmt.id}/invoice", headers=headers)
            print(f"Status: {res_inv1.status_code}, Content-Type: {res_inv1.headers.get('content-type')}")
            assert res_inv1.status_code == 200, f"Expected 200, got {res_inv1.status_code}: {res_inv1.text}"
            assert res_inv1.headers.get("content-type") == "application/pdf", "Expected application/pdf"
            print("[OK] Subscription invoice download passed!")

            print("\n--- 3. Testing GET /api/v1/payments/{fruit_order_id}/invoice for Fruit Order ---")
            res_inv2 = await client.get(f"/api/v1/payments/{fruit_order.id}/invoice", headers=headers)
            print(f"Status: {res_inv2.status_code}, Content-Type: {res_inv2.headers.get('content-type')}")
            assert res_inv2.status_code == 200, f"Expected 200, got {res_inv2.status_code}: {res_inv2.text}"
            assert res_inv2.headers.get("content-type") == "application/pdf", "Expected application/pdf"
            print("[OK] Fruit order invoice download passed!")

            print("\n--- 4. Testing Multi-package Cart Checkout -> Separate Subscriptions ---")
            # Add prod1 and prod2 to package cart
            cart1 = PackageCart(customer_id=cust.id, product_id=prod1.id, quantity=1, unit_price=1200.0, subtotal=1200.0)
            cart2 = PackageCart(customer_id=cust.id, product_id=prod2.id, quantity=1, unit_price=4500.0, subtotal=4500.0)
            session.add_all([cart1, cart2])
            await session.commit()

            res_chk = await client.post(
                "/api/v1/packages/orders/checkout",
                json={"address_id": str(addr.id)},
                headers=headers
            )
            print(f"Checkout Status: {res_chk.status_code}, Response: {res_chk.json()}")
            assert res_chk.status_code == 200, f"Checkout failed: {res_chk.text}"

            # Verify that 2 separate subscriptions were created
            subs_res = await session.execute(
                select(Subscription).where(
                    Subscription.customer_id == cust.id,
                    Subscription.status == SubscriptionStatus.PENDING_PAYMENT
                )
            )
            created_subs = subs_res.scalars().all()
            print(f"Created {len(created_subs)} separate pending subscriptions for multi-item cart checkout")
            assert len(created_subs) == 2, f"Expected 2 separate subscriptions, got {len(created_subs)}"
            print("[OK] Multi-package split subscription checkout passed!")

            # Clean up test data: delete payments first
            pmts_res = await session.execute(select(Payment).where(Payment.customer_id == cust.id))
            for p in pmts_res.scalars().all():
                await session.delete(p)

            await session.delete(cart1)
            await session.delete(cart2)
            for s in created_subs:
                await session.delete(s)
            await session.delete(sub1)
            await session.delete(fruit_order)
            await session.delete(prod1)
            await session.delete(prod2)
            await session.delete(cat)
            await session.delete(addr)
            await session.delete(cust)
            await session.delete(cust_user)
            await session.commit()

            print("\n==============================================")
            print("ALL CUSTOMER ENHANCEMENT TESTS PASSED SUCCESSFULLY!")
            print("==============================================")

if __name__ == "__main__":
    asyncio.run(test_customer_features())
