import asyncio
import uuid
import httpx
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.models.user import User, UserRoleEnum
from app.core.security import create_access_token
from app.main import app
from app.db.base import Base

DATABASE_URL = getattr(settings, "DATABASE_URL", "sqlite+aiosqlite:///healthyhomefoods.db")
engine = create_async_engine(DATABASE_URL, echo=False)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def test_grocery_category_and_item_flow():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        from sqlalchemy import text
        try:
            await conn.execute(text("ALTER TABLE product_categories ADD COLUMN category_type VARCHAR(50) DEFAULT 'package'"))
        except Exception:
            pass
        try:
            await conn.execute(text("ALTER TABLE fruits ADD COLUMN category_id CHAR(36)"))
            await conn.execute(text("ALTER TABLE fruits ADD COLUMN category_name VARCHAR(150)"))
        except Exception:
            pass

    async with AsyncSessionLocal() as session:
        # Create super admin user for testing
        admin_uid = uuid.uuid4()
        admin_user = User(
            id=admin_uid,
            email=f"grocery_admin_{admin_uid.hex[:6]}@example.com",
            phone=f"99{uuid.uuid4().int % 100000000:08d}",
            full_name="Grocery Admin",
            role=UserRoleEnum.SUPER_ADMIN
        )
        session.add(admin_user)
        await session.commit()

        token = create_access_token(data={"sub": str(admin_user.id), "role": admin_user.role.value})
        headers = {"Authorization": f"Bearer {token}"}

        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
            print("\n--- 1. Testing POST /api/v1/categories (Grocery Category) ---")
            cat_payload = {
                "name": "Organic Vegetables",
                "slug": f"organic-vegetables-{uuid.uuid4().hex[:6]}",
                "description": "Fresh organic farm vegetables",
                "category_type": "grocery"
            }
            res_cat = await client.post("/api/v1/categories", json=cat_payload, headers=headers)
            print(f"Status: {res_cat.status_code}, Response: {res_cat.json()}")
            assert res_cat.status_code == 200
            category = res_cat.json()
            assert category["category_type"] == "grocery"
            category_id = category["id"]

            print("\n--- 2. Testing GET /api/v1/categories?category_type=grocery ---")
            res_list = await client.get("/api/v1/categories?category_type=grocery")
            print(f"Status: {res_list.status_code}")
            assert res_list.status_code == 200
            cats = res_list.json()
            assert any(c["id"] == category_id for c in cats), "Created grocery category should be returned"

            print("\n--- 3. Testing POST /api/v1/fruits/admin/fruits (Grocery Item Creation with category_id) ---")
            item_payload = {
                "category_id": category_id,
                "name": "Organic Tomatoes",
                "description": "Farm fresh tomatoes",
                "price_per_kg": 45.0,
                "availability_status": "in_stock",
                "is_active": True
            }
            res_item = await client.post("/api/v1/fruits/admin/fruits", json=item_payload, headers=headers)
            print(f"Status: {res_item.status_code}, Response: {res_item.json()}")
            assert res_item.status_code == 201
            item_data = res_item.json()
            assert item_data["category_id"] == category_id
            assert item_data["category_name"] == "Organic Vegetables"

            print("\n==============================================")
            print("GROCERY CATEGORY & ITEM CREATION TEST PASSED!")
            print("==============================================")

if __name__ == "__main__":
    asyncio.run(test_grocery_category_and_item_flow())
