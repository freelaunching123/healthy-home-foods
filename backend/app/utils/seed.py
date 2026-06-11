import asyncio
import logging
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import AsyncSessionLocal
from app.models.role import Role, UserRole
from app.models.user import User
from app.models.admin_settings import AdminSettings
from app.models.product import ProductCategory, Product
from app.db.models_import import *  # Ensures all models are registered for relationships
from app.core.security import hash_password

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def slugify(text: str) -> str:
    import re
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[-\s]+', '-', text)
    return text

async def seed_data():
    async with AsyncSessionLocal() as db:
        # 1. Seed Roles
        roles = ["super_admin", "customer", "delivery_boy"]
        for role_name in roles:
            result = await db.execute(select(Role).where(Role.name == role_name))
            if not result.scalar_one_or_none():
                db.add(Role(name=role_name))
                logger.info(f"Seeded role: {role_name}")
        await db.commit()

        # 2. Seed Admin User
        admin_phone = "9876543210"
        result = await db.execute(select(User).where(User.phone == admin_phone))
        admin = result.scalar_one_or_none()
        if not admin:
            admin = User(
                phone=admin_phone,
                full_name="Super Admin",
                password_hash=hash_password("Admin123"),
                is_verified=True,
            )
            db.add(admin)
            await db.flush()
            
            # Assign super_admin role
            role_result = await db.execute(select(Role).where(Role.name == "super_admin"))
            super_admin_role = role_result.scalar_one()
            db.add(UserRole(user_id=admin.id, role_id=super_admin_role.id))
            logger.info("Seeded super_admin user")
        await db.commit()

        # 3. Seed Admin Settings
        result = await db.execute(select(AdminSettings).where(AdminSettings.id == 1))
        settings = result.scalar_one_or_none()
        if not settings:
            settings = AdminSettings(
                free_delivery_radius_km=5.0,
                delivery_charge_per_km=10.0,
                weekly_deliveries=6,
                monthly_deliveries=26,
                working_hours_start="07:00",
                working_hours_end="19:00",
                service_available=True,
                tax_percentage=0.0
            )
            db.add(settings)
            logger.info("Seeded Admin Settings")
        await db.commit()

        # 4. Seed Product Categories
        categories = [
            "Fruit Packs",
            "Healthy Meals",
            "Protein Salads",
            "Millet Porridge",
            "Sandwich Fruit Box",
            "Elite Combos"
        ]
        cat_map = {}
        for idx, cat_name in enumerate(categories):
            result = await db.execute(select(ProductCategory).where(ProductCategory.name == cat_name))
            cat = result.scalar_one_or_none()
            if not cat:
                cat = ProductCategory(
                    name=cat_name,
                    slug=slugify(cat_name),
                    sort_order=idx
                )
                db.add(cat)
                await db.flush()
                logger.info(f"Seeded category: {cat_name}")
            cat_map[cat_name] = cat
        await db.commit()

        # 5. Seed Products
        products_data = [
            {"name": "Millet Porridge", "category": "Millet Porridge", "weekly": 510, "monthly": 2080},
            {"name": "Fresh Fruits - Basic Pack", "category": "Fruit Packs", "weekly": None, "monthly": 1560},
            {"name": "Fresh Fruits - Mini Pack", "category": "Fruit Packs", "weekly": None, "monthly": 2080},
            {"name": "Fresh Fruits - Medium Pack", "category": "Fruit Packs", "weekly": None, "monthly": 2600},
            {"name": "Fresh Fruits - Premium Pack", "category": "Fruit Packs", "weekly": None, "monthly": 3120},
            {"name": "Protein Salads", "category": "Protein Salads", "weekly": 899, "monthly": 3899},
            {"name": "Healthy Meals - Medium Pro Pack", "category": "Healthy Meals", "weekly": 720, "monthly": 2990},
            {"name": "Healthy Meals - Premium Pro Pack", "category": "Healthy Meals", "weekly": 930, "monthly": 3900},
            {"name": "Sandwich Fruit Box - Premium", "category": "Sandwich Fruit Box", "weekly": 930, "monthly": 3900},
            {"name": "Sandwich Fruit Box - Club", "category": "Sandwich Fruit Box", "weekly": 1110, "monthly": 4680},
            {"name": "Elite Combo 1", "category": "Elite Combos", "weekly": None, "monthly": 3380},
            {"name": "Elite Combo 2", "category": "Elite Combos", "weekly": None, "monthly": 4420},
            {"name": "Elite Combo 3", "category": "Elite Combos", "weekly": None, "monthly": 5460},
        ]

        for p_data in products_data:
            result = await db.execute(select(Product).where(Product.name == p_data["name"]))
            p = result.scalar_one_or_none()
            if not p:
                cat = cat_map.get(p_data["category"])
                if cat:
                    # In this DB schema, we don't have separate weekly/monthly pricing on the Product table itself,
                    # we have `price_per_unit`. For simplicity, we can calculate base price from the monthly plan
                    # e.g., price = monthly / 26
                    base_price = round(p_data["monthly"] / 26, 2)
                    product = Product(
                        category_id=cat.id,
                        name=p_data["name"],
                        slug=slugify(p_data["name"]),
                        description=f"Delicious {p_data['name']}",
                        price_per_unit=base_price,
                        unit="pack",
                        is_available=True
                    )
                    db.add(product)
                    logger.info(f"Seeded product: {p_data['name']}")
        await db.commit()
        logger.info("✅ Database seeding complete!")

if __name__ == "__main__":
    asyncio.run(seed_data())
