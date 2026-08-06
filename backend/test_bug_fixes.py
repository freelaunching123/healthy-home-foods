import asyncio
import io
import uuid
import httpx
from datetime import date, datetime, timezone
from app.models.payment import Payment, PaymentStatus
from sqlalchemy import select, delete

from app.main import app as fastapi_app
from app.db.session import get_db
from app.core.dependencies import require_super_admin
from app.models.user import User, UserRoleEnum
from app.models.customer import Customer
from app.models.product import Product, ProductCategory, ProductStatus, ProductAvailability
from app.models.subscription import Subscription, SubscriptionStatus, PlanType
from app.models.fruit import FruitOrder, FruitPaymentStatus, FruitOrderStatus

def override_require_super_admin():
    return User(
        id=uuid.UUID("00000000-0000-0000-0000-000000000000"),
        role=UserRoleEnum.SUPER_ADMIN,
        full_name="Test Super Admin",
        phone="9999999999"
    )

from app.db.base import Base
import app.db.models_import  # noqa
from app.db.session import async_engine

fastapi_app.dependency_overrides[require_super_admin] = override_require_super_admin

async def test_fixes():
    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=fastapi_app), base_url="http://test") as client:
        print("--- 1. Testing Product Package Image Upload ---")
        # First create a dummy product category and product
        cat_id = str(uuid.uuid4())
        product_id = uuid.uuid4()
        async for session in get_db():
            cat = ProductCategory(id=uuid.UUID(cat_id), name="Test Category", slug=f"test-cat-{uuid.uuid4()}")
            session.add(cat)
            await session.commit()
            
            prod = Product(
                id=product_id,
                name="Test Package Product",
                slug=f"test-pkg-{uuid.uuid4()}",
                category_id=uuid.UUID(cat_id),
                plan_type=PlanType.WEEKLY,
                package_price=500.0,
                package_days=6,
                status=ProductStatus.PUBLISHED,
                availability=ProductAvailability.AVAILABLE
            )
            session.add(prod)
            await session.commit()
            break

        # Test uploading an image to the product
        dummy_image = io.BytesIO(b"fake image bytes content")
        files = {"file": ("test_product_img.png", dummy_image, "image/png")}
        
        response = await client.post(f"/api/v1/products/{product_id}/image", files=files)
        print(f"Image Upload Response Status: {response.status_code}")
        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"
        res_json = response.json()
        print(f"Uploaded Image URL: {res_json.get('image_url')}")
        assert res_json.get("image_url") is not None, "image_url should not be None"
        print("[OK] Image Upload test passed!")

        print("\n--- 2. Testing Admin Overview Today's Orders Filter ---")
        cust_id = uuid.uuid4()
        cust_user_id = uuid.uuid4()
        # Create test customer & orders (1 paid sub, 1 unpaid sub, 1 paid fruit order, 1 unpaid fruit order)
        async for session in get_db():
            cust_user = User(
                id=cust_user_id,
                role=UserRoleEnum.CUSTOMER,
                full_name="Test Customer",
                phone=f"88{uuid.uuid4().int % 100000000:08d}"
            )
            session.add(cust_user)
            await session.flush()

            cust = Customer(id=cust_id, user_id=cust_user.id, customer_code=f"CUST-{uuid.uuid4().hex[:6]}")
            session.add(cust)
            await session.flush()

            # Add 1 Paid Sub (ACTIVE) & 1 Unpaid Sub (PENDING_PAYMENT)
            paid_sub = Subscription(
                id=uuid.uuid4(),
                customer_id=cust_id,
                product_id=product_id,
                address_id=uuid.uuid4(),
                status=SubscriptionStatus.ACTIVE,
                total_deliveries=6,
                total_amount=500.0
            )
            unpaid_sub = Subscription(
                id=uuid.uuid4(),
                customer_id=cust_id,
                product_id=product_id,
                address_id=uuid.uuid4(),
                status=SubscriptionStatus.PENDING_PAYMENT,
                total_deliveries=6,
                total_amount=500.0
            )
            session.add_all([paid_sub, unpaid_sub])

            # Successful payment record for paid_sub
            paid_pmt = Payment(
                id=uuid.uuid4(),
                subscription_id=paid_sub.id,
                customer_id=cust_id,
                amount=500.0,
                status=PaymentStatus.SUCCESS,
                paid_at=datetime.now(timezone.utc)
            )
            session.add(paid_pmt)

            # Add 1 Paid Fruit Order (SUCCESS) & 1 Unpaid Fruit Order (PENDING)
            paid_fruit = FruitOrder(
                id=uuid.uuid4(),
                customer_id=cust_id,
                order_number=f"FO-PAID-{uuid.uuid4().hex[:6]}",
                total_amount=200.0,
                payment_status=FruitPaymentStatus.SUCCESS,
                paid_at=datetime.now(timezone.utc),
                order_status=FruitOrderStatus.PENDING
            )
            unpaid_fruit = FruitOrder(
                id=uuid.uuid4(),
                customer_id=cust_id,
                order_number=f"FO-UNPAID-{uuid.uuid4().hex[:6]}",
                total_amount=200.0,
                payment_status=FruitPaymentStatus.PENDING,
                order_status=FruitOrderStatus.PENDING
            )
            session.add_all([paid_fruit, unpaid_fruit])
            await session.commit()
            break

        # Query admin overview endpoint
        ov_res = await client.get("/api/v1/reports/admin-overview")
        print(f"Admin Overview Response Status: {ov_res.status_code}")
        assert ov_res.status_code == 200, f"Expected 200, got {ov_res.status_code}: {ov_res.text}"
        ov_data = ov_res.json()
        summary = ov_data.get("summary", {})
        orders_today = summary.get("orders_today")
        print(f"Orders Today in Summary: {orders_today}")
        assert orders_today == 2, f"Expected 2 paid orders today, but got {orders_today}"
        
        # We inserted 1 paid sub + 1 paid fruit order today (= 2 paid orders), plus 1 unpaid sub + 1 unpaid fruit order.
        # Check that orders_today counts only the paid ones.
        print("[OK] Admin Overview test completed successfully!")

        # Clean up created test data
        async for session in get_db():
            await session.execute(delete(Subscription).where(Subscription.customer_id == cust_id))
            await session.execute(delete(FruitOrder).where(FruitOrder.customer_id == cust_id))
            await session.execute(delete(Customer).where(Customer.id == cust_id))
            await session.execute(delete(User).where(User.id == cust_user_id))
            await session.execute(delete(Product).where(Product.id == product_id))
            await session.execute(delete(ProductCategory).where(ProductCategory.id == uuid.UUID(cat_id)))
            await session.commit()
            break

if __name__ == "__main__":
    asyncio.run(test_fixes())
