import asyncio
from sqlalchemy import select
from app.db.session import SessionLocal
from app.models.subscription import Subscription
from sqlalchemy.orm import selectinload
from app.models.customer import Customer
from app.models.subscription import SubscriptionItem

async def main():
    async with SessionLocal() as db:
        try:
            stmt = (
                select(Subscription)
                .options(
                    selectinload(Subscription.customer).selectinload(Customer.user),
                    selectinload(Subscription.items).selectinload(SubscriptionItem.product),
                    selectinload(Subscription.payments),
                )
                .order_by(Subscription.created_at.desc())
            )
            result = await db.execute(stmt)
            subscriptions = result.scalars().all()
            for sub in subscriptions:
                print("Sub ID:", sub.id, "Delivery partner:", sub.delivery_partner_id)
            print("Success")
        except Exception as e:
            print("ERROR:", e)

if __name__ == "__main__":
    asyncio.run(main())
