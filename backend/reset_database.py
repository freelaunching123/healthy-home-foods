import sys
import os
import asyncio
from sqlalchemy import text, select

sys.path.insert(0, "/app")

os.environ["DATABASE_URL"] = "postgresql+asyncpg://hhf_user:hhf_password@db:5432/healthy_home_foods"

import app.db.models_import  # noqa
from app.db.session import AsyncSessionLocal
from app.models.user import User, UserRoleEnum

tables_to_clear = [
    "fruit_carts",
    "package_carts",
    "fruit_order_items",
    "fruit_orders",
    "invoices",
    "payments",
    "delivery_assignments",
    "subscription_deliveries",
    "subscription_items",
    "subscriptions",
    "gps_tracking_logs",
    "reviews",
    "delivery_slots",
    "notifications",
    "notification_history",
    "otp_logs",
    "audit_logs",
    "addresses",
    "customers",
    "delivery_partners",
]

async def clean_database():
    print("\n==========================================")
    print("Database Cleanup & Reset Execution (Container)")
    print("==========================================")
    
    async with AsyncSessionLocal() as db:
        for table in tables_to_clear:
            try:
                res = await db.execute(text(f"DELETE FROM {table}"))
                print(f"  - Cleared table: {table}")
            except Exception as e:
                print(f"  ! Table {table} note: {e}")

        # Delete non-admin users
        res = await db.execute(text("DELETE FROM users WHERE role NOT IN ('admin', 'super_admin')"))
        print(f"  - Removed non-admin user logins. (Rows deleted: {res.rowcount})")

        await db.commit()
        print("  - Transaction committed successfully.")

        # Query preserved Admin users
        admin_res = await db.execute(
            select(User).where(User.role.in_([UserRoleEnum.ADMIN, UserRoleEnum.SUPER_ADMIN]))
        )
        admins = admin_res.scalars().all()
        print(f"\nPreserved Admin Users ({len(admins)}):")
        for admin in admins:
            print(f"  - ID: {admin.id} | Name: {admin.full_name} | Phone: {admin.phone} | Role: {admin.role.value if hasattr(admin.role, 'value') else admin.role}")

        # Verify row counts for all tables
        print("\nVerification of Table Row Counts:")
        all_tables = tables_to_clear + ["users"]
        for tbl in all_tables:
            count_res = await db.execute(text(f"SELECT COUNT(*) FROM {tbl}"))
            count = count_res.scalar()
            print(f"  - Table '{tbl}': {count} rows")

if __name__ == "__main__":
    asyncio.run(clean_database())
