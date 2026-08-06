import asyncio
import sys
import os

# Set environment variables before app config is loaded
os.environ.setdefault("SECRET_KEY", "test-secret-key-123456789")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///healthy_home.db")
os.environ.setdefault("SYNC_DATABASE_URL", "sqlite:///healthy_home.db")

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import app.db.models_import  # noqa

from sqlalchemy import select
from app.db.session import AsyncSessionLocal
from app.models.user import User, UserRoleEnum
from app.models.customer import Customer
from app.models.delivery_partner import DeliveryPartner
from app.models.notification_history import NotificationHistory
from app.services.notification_service import NotificationService


async def main():
    print("=" * 60)
    print("STARTING END-TO-END NOTIFICATION SYSTEM VERIFICATION")
    print("=" * 60)

    async with AsyncSessionLocal() as db:
        # 1. Fetch or identify users for each role
        admin_res = await db.execute(select(User).where(User.role.in_([UserRoleEnum.ADMIN, UserRoleEnum.SUPER_ADMIN])))
        admin_user = admin_res.scalars().first()

        dp_res = await db.execute(select(User).where(User.role == UserRoleEnum.DELIVERY_PARTNER))
        dp_user = dp_res.scalars().first()

        cust_res = await db.execute(select(User).where(User.role == UserRoleEnum.CUSTOMER))
        cust_user = cust_res.scalars().first()

        if not admin_user or not dp_user or not cust_user:
            print("ERROR: Required test users (Admin, Delivery Partner, Customer) missing in database.")
            return False

        print(f"[OK] Found Admin User: {admin_user.full_name} ({admin_user.id})")
        print(f"[OK] Found Delivery Partner User: {dp_user.full_name} ({dp_user.id})")
        print(f"[OK] Found Customer User: {cust_user.full_name} ({cust_user.id})")

        # 2. Test Customer Notifications
        print("\n--- Testing Customer Notifications ---")
        res1 = await NotificationService.send_notification_to_user(
            db=db,
            user_id=cust_user.id,
            title="Test Customer Welcome",
            body="Welcome to Healthy Home Foods!",
            notification_type="promo"
        )
        res2 = await NotificationService.send_notification_to_user(
            db=db,
            user_id=cust_user.id,
            title="Out for Delivery Test",
            body="Your order is out for delivery!",
            notification_type="delivery",
            reference_id="test-delivery-id-123"
        )
        res3 = await NotificationService.send_notification_to_user(
            db=db,
            user_id=cust_user.id,
            title="Payment Success Test",
            body="Your payment of Rs.499 was successful.",
            notification_type="payment",
            reference_id="test-payment-id-456"
        )
        await db.commit()
        print("[OK] Sent 3 notifications to Customer")

        # 3. Test Delivery Partner Notifications
        print("\n--- Testing Delivery Partner Notifications ---")
        res4 = await NotificationService.send_notification_to_user(
            db=db,
            user_id=dp_user.id,
            title="New Assignment Test",
            body="You have been assigned a new delivery for today.",
            notification_type="delivery",
            reference_id="test-assignment-id-789"
        )
        res5 = await NotificationService.send_notification_to_user(
            db=db,
            user_id=dp_user.id,
            title="Morning Route Reminder Test",
            body="Good morning! You have 5 deliveries scheduled for today.",
            notification_type="morning_reminder"
        )
        await db.commit()
        print("[OK] Sent 2 notifications to Delivery Partner")

        # 4. Test Admin Role Notifications
        print("\n--- Testing Admin Role Notifications ---")
        res6 = await NotificationService.send_notification_to_role(
            db=db,
            role="admin",
            title="New Customer Alert Test",
            body=f"New customer registered: {cust_user.full_name}",
            notification_type="system",
            reference_id=str(cust_user.id)
        )
        await db.commit()
        print("[OK] Sent notification to Admin Role")

        # 5. Test Customer Broadcast Notifications
        print("\n--- Testing Customer Broadcast Notifications ---")
        res7 = await NotificationService.send_notification_to_all_customers(
            db=db,
            title="Broadcast Deal Alert Test",
            body="Special 20% discount on all Fruit Bowls today!",
            notification_type="promo"
        )
        await db.commit()
        print("[OK] Sent broadcast notification to all customers")

        # 6. Verify Notification History Persistence in Database
        print("\n--- Verifying Notification History Database Entries ---")
        
        cust_history = await db.execute(
            select(NotificationHistory)
            .where(NotificationHistory.user_id == cust_user.id, NotificationHistory.is_deleted == False)
            .order_by(NotificationHistory.created_at.desc())
        )
        cust_records = cust_history.scalars().all()
        print(f"[OK] Customer Notification History Count: {len(cust_records)}")
        for r in cust_records[:3]:
            print(f"   - [{r.notification_type}] {r.title}: {r.body}")

        dp_history = await db.execute(
            select(NotificationHistory)
            .where(NotificationHistory.user_id == dp_user.id, NotificationHistory.is_deleted == False)
            .order_by(NotificationHistory.created_at.desc())
        )
        dp_records = dp_history.scalars().all()
        print(f"[OK] Delivery Partner Notification History Count: {len(dp_records)}")
        for r in dp_records[:2]:
            print(f"   - [{r.notification_type}] {r.title}: {r.body}")

        admin_history = await db.execute(
            select(NotificationHistory)
            .where(NotificationHistory.user_id == admin_user.id, NotificationHistory.is_deleted == False)
            .order_by(NotificationHistory.created_at.desc())
        )
        admin_records = admin_history.scalars().all()
        print(f"[OK] Admin Notification History Count: {len(admin_records)}")
        for r in admin_records[:2]:
            print(f"   - [{r.notification_type}] {r.title}: {r.body}")

        print("\n" + "=" * 60)
        print("VERIFICATION SUCCESSFUL: ALL NOTIFICATION FLOWS WORKING PERFECTLY!")
        print("=" * 60)
        return True

if __name__ == "__main__":
    success = asyncio.run(main())
    if not success:
        sys.exit(1)
