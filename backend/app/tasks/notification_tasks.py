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


@celery_app.task(name="app.tasks.notification_tasks.send_scheduled_notification_task")
def send_scheduled_notification_task(user_id: str, title: str, body: str, notification_type: str, reference_id: str = None):
    """Celery task to send scheduled notification to a user."""
    async def _run():
        async with AsyncSessionLocal() as db:
            await NotificationService.send_notification_to_user(
                db=db,
                user_id=user_id,
                title=title,
                body=body,
                notification_type=notification_type,
                reference_id=reference_id
            )
            await db.commit()
    asyncio.run(_run())


@celery_app.task(name="app.tasks.notification_tasks.send_delivery_boy_morning_reminders")
def send_delivery_boy_morning_reminders():
    """Send morning reminder to all active delivery partners with today's count."""
    async def _run():
        async with AsyncSessionLocal() as db:
            from app.models.delivery_partner import DeliveryPartner
            from app.models.delivery_assignment import DeliveryAssignment
            from app.models.subscription_delivery import SubscriptionDelivery
            from app.models.fruit import FruitOrder
            from sqlalchemy import func
            
            result = await db.execute(
                select(DeliveryPartner).where(DeliveryPartner.is_available == True)
            )
            partners = result.scalars().all()
            today = date.today()
            
            for partner in partners:
                sub_count = await db.scalar(
                    select(func.count(DeliveryAssignment.id))
                    .join(SubscriptionDelivery, DeliveryAssignment.subscription_delivery_id == SubscriptionDelivery.id)
                    .where(
                        DeliveryAssignment.delivery_partner_id == partner.id,
                        SubscriptionDelivery.scheduled_date == today
                    )
                ) or 0
                
                fruit_count = await db.scalar(
                    select(func.count(DeliveryAssignment.id))
                    .join(FruitOrder, DeliveryAssignment.fruit_order_id == FruitOrder.id)
                    .where(
                        DeliveryAssignment.delivery_partner_id == partner.id,
                        func.date(FruitOrder.created_at) == today
                    )
                ) or 0
                
                total_today = sub_count + fruit_count
                
                user = await db.get(User, partner.user_id)
                if user:
                    await NotificationService.send_notification_to_user(
                        db=db,
                        user_id=user.id,
                        title="Morning Delivery Reminder",
                        body=f"Good morning! You have {total_today} deliveries scheduled for today.",
                        notification_type="morning_reminder"
                    )
            await db.commit()
    asyncio.run(_run())
