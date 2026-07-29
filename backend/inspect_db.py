import asyncio
import asyncpg
from app.core.config import settings

async def inspect():
    db_url = settings.DATABASE_URL.replace("postgresql+asyncpg", "postgresql")
    conn = await asyncpg.connect(db_url)
    
    # Get partners
    partners = await conn.fetch("SELECT dp.id, u.full_name FROM delivery_partners dp JOIN users u ON u.id = dp.user_id")
    for p in partners:
        print(f"Partner: {p['full_name']} (ID: {p['id']})")
        
    print("\n--- Assignments ---")
    assignments = await conn.fetch("SELECT id, status, delivery_partner_id, subscription_delivery_id, fruit_order_id, assigned_at, delivered_at FROM delivery_assignments")
    print(f"Total assignments: {len(assignments)}")
    for a in assignments:
        print(dict(a))
        
    print("\n--- Subscription Deliveries ---")
    sub_dels = await conn.fetch("SELECT id, subscription_id, status, scheduled_date FROM subscription_deliveries")
    for s in sub_dels:
        print(dict(s))
        
    await conn.close()
    
if __name__ == "__main__":
    asyncio.run(inspect())
