import asyncio
from sqlalchemy import text
from app.db.session import AsyncSessionLocal

async def clear_database():
    print("Clearing database (keeping admins and products/settings)...")
    async with AsyncSessionLocal() as db:
        try:
            # We must use DELETE in the correct order to avoid foreign key violations.
            # Order: children first, parents later.
            
            queries = [
                "DELETE FROM otp_logs;",
                "DELETE FROM audit_logs;",
                "DELETE FROM delivery_assignments;",
                "DELETE FROM delivery_partners;",
                "DELETE FROM subscription_pause_history;",
                "DELETE FROM subscription_status_history;",
                "DELETE FROM subscription_payment_history;",
                "DELETE FROM subscription_deliveries;",
                "DELETE FROM subscription_items;",
                "DELETE FROM invoices;",
                "DELETE FROM payments;",
                "DELETE FROM package_cart;",
                "DELETE FROM fruit_cart;",
                "DELETE FROM subscriptions;",
                "DELETE FROM addresses;",
                "DELETE FROM support_tickets;",
                "DELETE FROM reviews;",
                "DELETE FROM notifications;",
                "DELETE FROM notification_history;",
                "DELETE FROM customers;",
                "DELETE FROM users WHERE role NOT IN ('admin', 'super_admin');"
            ]
            
            for q in queries:
                try:
                    await db.execute(text(q))
                    print(f"Executed: {q}")
                except Exception as e:
                    # Ignore if table doesn't exist, otherwise print error
                    if "does not exist" not in str(e):
                        print(f"Error on {q}: {e}")
                    else:
                        print(f"Skipped {q} (table doesn't exist)")
                    
            await db.commit()
            print("Successfully cleared all user data!")
        except Exception as e:
            await db.rollback()
            print(f"Failed to clear database: {e}")

if __name__ == "__main__":
    asyncio.run(clear_database())
