import asyncio
import logging
from datetime import date, timedelta
from sqlalchemy import select, and_

from app.tasks.celery_app import celery_app
from app.db.session import AsyncSessionLocal
from app.models.subscription import Subscription, SubscriptionStatus
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.user import User
from app.models.customer import Customer
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.notification_tasks.send_morning_delivery_notifications")
def send_morning_delivery_notifications():
    """Notify customers whose delivery is scheduled for today."""
    async def _run():
        async with AsyncSessionLocal() as db:
            today = date.today()
            result = await db.execute(
                select(SubscriptionDelivery)
                .where(and_(
                    SubscriptionDelivery.scheduled_date == today,
                    SubscriptionDelivery.status.in_([
                        DeliveryStatus.PENDING, DeliveryStatus.ASSIGNED
                    ])
                ))
            )
            deliveries = result.scalars().all()
            for delivery in deliveries:
                sub = await db.get(Subscription, delivery.subscription_id)
                customer = await db.get(Customer, sub.customer_id)
                user = await db.get(User, customer.user_id)
                logger.info(f"[NOTIFY] Delivery today for {user.phone}: {delivery.id}")
                await NotificationService.send_push_notification(
                    user_id=str(user.id),
                    title="Delivery Arriving Today",
                    body=f"Your healthy meal delivery is scheduled for today. Track it in the app!",
                    data={"delivery_id": str(delivery.id), "type": "delivery_update"}
                )
    asyncio.run(_run())


@celery_app.task(name="app.tasks.notification_tasks.send_expiry_reminders")
def send_expiry_reminders():
    """Remind customers whose subscription ends in 2 days."""
    async def _run():
        async with AsyncSessionLocal() as db:
            in_two_days = date.today() + timedelta(days=2)
            result = await db.execute(
                select(Subscription).where(
                    and_(
                        Subscription.status == SubscriptionStatus.ACTIVE,
                        Subscription.expected_end_date == in_two_days,
                    )
                )
            )
            for sub in result.scalars().all():
                customer = await db.get(Customer, sub.customer_id)
                user = await db.get(User, customer.user_id)
                logger.info(f"[NOTIFY] Subscription expiring in 2 days for {user.phone}")
                await NotificationService.send_push_notification(
                    user_id=str(user.id),
                    title="Subscription Expiring Soon",
                    body=f"Your healthy meal subscription expires in 2 days. Renew now to avoid interruption!",
                    data={"subscription_id": str(sub.id), "type": "subscription_expiry"}
                )
                await NotificationService.send_sms(
                    phone_number=user.phone,
                    message=f"Hi {user.full_name}, your Healthy Home Foods subscription expires in 2 days. Renew via the app to keep receiving fresh meals!"
                )
    asyncio.run(_run())
