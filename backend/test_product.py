import asyncio
import uuid
import app.main
from sqlalchemy import text
from app.db.session import AsyncSessionLocal
from app.api.v1.products import create_product
from app.schemas.product import ProductCreate

async def test():
    async with AsyncSessionLocal() as db:
        res = await db.execute(text("SELECT id FROM product_categories LIMIT 1"))
        cat_id = res.scalar()
        if not cat_id:
            print('No categories')
            return
        
        payload = ProductCreate(
            category_id=cat_id,
            name='Test Product Valid',
            slug='test-product-valid',
            description='Test',
            package_price=100.0,
            plan_type='weekly',
            package_days=6
        )
        try:
            res = await create_product(payload=payload, _=None, db=db)
            print('Success', res.name)
        except Exception as e:
            import traceback
            traceback.print_exc()

asyncio.run(test())
