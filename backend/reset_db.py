import sys
import os

# Set up path so it can be run directly
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.models_import import *
from app.db.session import sync_engine
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.models.user import User, UserRoleEnum, UserStatus
from app.models.admin import Admin
from app.core.security import hash_password

def reset_database():
    print("Connecting to database:", sync_engine.url)
    
    with sync_engine.connect() as conn:
        print("Truncating all transactional tables...")
        truncate_sql = """
        TRUNCATE TABLE 
            users,
            admins,
            customers,
            delivery_partners,
            addresses,
            audit_logs,
            delivery_assignments,
            delivery_assignment_history,
            fruit_carts,
            fruit_orders,
            fruit_order_items,
            gps_tracking_logs,
            invoices,
            notifications,
            notification_history,
            otp_logs,
            package_carts,
            payments,
            reviews,
            subscriptions,
            subscription_items,
            subscription_pause_history,
            subscription_status_history,
            subscription_payment_history,
            subscription_deliveries,
            subscription_delivery_history
        RESTART IDENTITY CASCADE;
        """
        conn.execute(text(truncate_sql))
        conn.commit()
        print("Tables truncated successfully!")

    with Session(sync_engine) as session:
        print("Creating Super Admin account...")
        user = User(
            phone="9876543210",
            full_name="Super Admin",
            role=UserRoleEnum.SUPER_ADMIN,
            status=UserStatus.ACTIVE,
            is_verified=True,
            password_hash=hash_password("Admin123")
        )
        session.add(user)
        session.flush()
        
        admin = Admin(
            user_id=user.id,
            is_super_admin=True,
            department="Management"
        )
        session.add(admin)
        session.commit()
        print("[+] Super Admin 9876543210 (Admin123) created successfully!")

if __name__ == "__main__":
    reset_database()
