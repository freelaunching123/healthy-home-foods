import asyncio
import uuid
from httpx import AsyncClient
from app.main import app
from app.core.security import create_access_token

async def test_flow():
    # 1. Create a super admin token
    access_token = create_access_token(subject="00000000-0000-0000-0000-000000000001", role="super_admin")
    headers = {"Authorization": f"Bearer {access_token}"}
    
    async with AsyncClient(app=app, base_url="http://test") as client:
        # 2. Get categories to get a valid category_id
        cat_res = await client.get("/api/v1/categories?active_only=true", headers=headers)
        cats = cat_res.json()
        if not cats:
            # Create a category
            cat_create = await client.post("/api/v1/categories", json={"name": "Test Cat", "slug": f"test-cat-{uuid.uuid4()}", "is_active": True, "sort_order": 0}, headers=headers)
            cats = [cat_create.json()]
            
        category_id = cats[0]["id"]
        print("Using category:", category_id)

        # 3. Create a product
        payload = {
            "name": "Test Product",
            "slug": f"test-product-{uuid.uuid4()}",
            "description": "Test Desc",
            "price": 100.0,
            "category_id": category_id,
            "status": "published",
            "availability": "available",
            "display_order": 0,
            "is_featured": False,
            "is_popular": False,
            "is_today_special": False
        }
        
        prod_res = await client.post("/api/v1/products/", json=payload, headers=headers)
        print("Create Product Status:", prod_res.status_code)
        print("Create Product Response:", prod_res.json())

if __name__ == "__main__":
    asyncio.run(test_flow())
