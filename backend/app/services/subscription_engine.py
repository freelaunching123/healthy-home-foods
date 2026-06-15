"""
Subscription Business Logic Engine
====================================
Enforces all subscription rules:
 - Weekly: 6 successful deliveries
 - Monthly: 26 successful deliveries
 - Only DELIVERED status counts toward completion
 - PAUSED days generate no deliveries
 - MISSED deliveries auto carry-forward to next available slot
 - Subscription completes only when completed == total
"""
import logging
from datetime import date, datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.models.subscription import Subscription, SubscriptionStatus, SubscriptionPlan
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.customer import Customer
from app.models.admin_settings import AdminSettings

logger = logging.getLogger(__name__)


async def get_settings(db: AsyncSession) -> AdminSettings:
    result = await db.execute(select(AdminSettings).where(AdminSettings.id == 1))
    return result.scalar_one_or_none()


async def create_subscription(
    db: AsyncSession,
    customer: Customer,
    plan: SubscriptionPlan,
    product_id: UUID,
    address_id: UUID,
    price_per_delivery: float,
    delivery_charge: float,
    tax_amount: float,
    preferred_delivery_time: str | None = None,
    auto_renew: bool = False,
    notes: str | None = None,
) -> Subscription:
    """Creates a subscription record. Status remains pending_payment until payment confirmed."""
    total_amount = (price_per_delivery * plan.total_deliveries) + delivery_charge + tax_amount

    sub = Subscription(
        customer_id=customer.id,
        plan_id=plan.id,
        product_id=product_id,
        address_id=address_id,
        status=SubscriptionStatus.PENDING_PAYMENT,
        total_deliveries=plan.total_deliveries,
        price_per_delivery=price_per_delivery,
        total_amount=total_amount,
        delivery_charge=delivery_charge,
        tax_amount=tax_amount,
        preferred_delivery_time=preferred_delivery_time,
        auto_renew=auto_renew,
        notes=notes,
    )
    db.add(sub)
    await db.flush()
    return sub


async def activate_subscription(db: AsyncSession, subscription: Subscription) -> Subscription:
    """Activates subscription after payment success and generates first delivery."""
    subscription.status = SubscriptionStatus.ACTIVE
    subscription.start_date = date.today()
    await db.flush()
    await _generate_next_delivery(db, subscription)
    return subscription


async def _generate_next_delivery(db: AsyncSession, subscription: Subscription) -> SubscriptionDelivery | None:
    """Generates next pending delivery for an active subscription if not already exists."""
    if subscription.status != SubscriptionStatus.ACTIVE:
        return None
    if subscription.completed_deliveries >= subscription.total_deliveries:
        await _complete_subscription(db, subscription)
        return None

    # Find latest scheduled delivery
    result = await db.execute(
        select(SubscriptionDelivery)
        .where(SubscriptionDelivery.subscription_id == subscription.id)
        .order_by(SubscriptionDelivery.scheduled_date.desc())
        .limit(1)
    )
    last = result.scalar_one_or_none()
    next_date = (last.scheduled_date + timedelta(days=1)) if last else date.today()

    # Skip Sundays (configurable in future)
    while next_date.weekday() == 6:
        next_date += timedelta(days=1)

    delivery = SubscriptionDelivery(
        subscription_id=subscription.id,
        scheduled_date=next_date,
        status=DeliveryStatus.PENDING,
    )
    db.add(delivery)
    await db.flush()
    logger.info(f"Generated delivery for sub {subscription.id} on {next_date}")
    return delivery


async def mark_delivered(db: AsyncSession, delivery: SubscriptionDelivery) -> None:
    """Marks a delivery as DELIVERED and advances subscription counter."""
    delivery.status = DeliveryStatus.DELIVERED
    delivery.delivered_at = datetime.now(timezone.utc)

    sub = await db.get(Subscription, delivery.subscription_id)
    sub.completed_deliveries += 1

    if sub.completed_deliveries >= sub.total_deliveries:
        await _complete_subscription(db, sub)
    else:
        await _generate_next_delivery(db, sub)


async def handle_missed_delivery(db: AsyncSession, delivery: SubscriptionDelivery) -> None:
    """Marks delivery as MISSED and carry-forwards to next available slot."""
    delivery.status = DeliveryStatus.MISSED
    sub = await db.get(Subscription, delivery.subscription_id)
    sub.missed_deliveries += 1

    settings = await get_settings(db)
    if settings and settings.allow_carry_forward:
        # Find next delivery date after latest scheduled
        result = await db.execute(
            select(SubscriptionDelivery)
            .where(SubscriptionDelivery.subscription_id == sub.id)
            .order_by(SubscriptionDelivery.scheduled_date.desc())
            .limit(1)
        )
        last = result.scalar_one_or_none()
        carry_date = (last.scheduled_date + timedelta(days=1)) if last else date.today()
        while carry_date.weekday() == 6:
            carry_date += timedelta(days=1)

        carry_delivery = SubscriptionDelivery(
            subscription_id=sub.id,
            scheduled_date=carry_date,
            status=DeliveryStatus.CARRY_FORWARD,
            parent_delivery_id=delivery.id,
            is_carry_forward=True,
        )
        db.add(carry_delivery)
        logger.info(f"Carry-forward delivery created for sub {sub.id} on {carry_date}")
    await db.flush()


async def pause_subscription(
    db: AsyncSession,
    subscription: Subscription,
    reason: str | None = None,
) -> Subscription:
    """Pause an active subscription. No new deliveries generated while paused."""
    if subscription.status != SubscriptionStatus.ACTIVE:
        raise ValueError("Only active subscriptions can be paused")

    settings = await get_settings(db)
    if settings and subscription.total_paused_days >= settings.max_pause_days_per_subscription:
        raise ValueError(f"Maximum pause limit ({settings.max_pause_days_per_subscription} days) reached")

    subscription.status = SubscriptionStatus.PAUSED
    subscription.paused_at = datetime.now(timezone.utc)
    subscription.pause_reason = reason
    return subscription


async def resume_subscription(db: AsyncSession, subscription: Subscription) -> Subscription:
    """Resume a paused subscription. Accumulates total_paused_days."""
    if subscription.status != SubscriptionStatus.PAUSED:
        raise ValueError("Subscription is not paused")

    if subscription.paused_at:
        paused_days = (datetime.now(timezone.utc) - subscription.paused_at).days
        subscription.total_paused_days += paused_days

    subscription.status = SubscriptionStatus.ACTIVE
    subscription.paused_at = None
    subscription.pause_reason = None

    # Generate next delivery from today
    await _generate_next_delivery(db, subscription)
    return subscription


async def cancel_subscription(db: AsyncSession, subscription: Subscription) -> Subscription:
    """Cancel a subscription. Refund handled separately via payment service."""
    subscription.status = SubscriptionStatus.CANCELLED
    subscription.actual_end_date = date.today()
    return subscription


async def skip_delivery(db: AsyncSession, delivery: SubscriptionDelivery) -> SubscriptionDelivery:
    """Marks a delivery as SKIPPED, deletes any active delivery boy assignment,
    increments subscription pause days, and schedules a carry-forward delivery."""
    if delivery.status in [DeliveryStatus.DELIVERED, DeliveryStatus.SKIPPED, DeliveryStatus.MISSED]:
        raise ValueError(f"Cannot skip delivery in status {delivery.status.value}")

    delivery.status = DeliveryStatus.SKIPPED
    sub = await db.get(Subscription, delivery.subscription_id)
    if not sub:
        raise ValueError("Subscription not found for this delivery")

    # Increment pause days
    sub.total_paused_days += 1

    # Remove active assignment if exists (using explicit select to avoid greenlet lazy load issues)
    from app.models.delivery_assignment import DeliveryAssignment
    assignment_res = await db.execute(
        select(DeliveryAssignment).where(DeliveryAssignment.delivery_id == delivery.id)
    )
    assignment = assignment_res.scalar_one_or_none()
    if assignment:
        await db.delete(assignment)

    # Find the latest scheduled delivery date for this subscription
    result = await db.execute(
        select(SubscriptionDelivery)
        .where(SubscriptionDelivery.subscription_id == sub.id)
        .order_by(SubscriptionDelivery.scheduled_date.desc())
        .limit(1)
    )
    last = result.scalar_one_or_none()
    carry_date = (last.scheduled_date + timedelta(days=1)) if last else date.today()
    while carry_date.weekday() == 6:
        carry_date += timedelta(days=1)

    carry_delivery = SubscriptionDelivery(
        subscription_id=sub.id,
        scheduled_date=carry_date,
        status=DeliveryStatus.CARRY_FORWARD,
        parent_delivery_id=delivery.id,
        is_carry_forward=True,
    )
    db.add(carry_delivery)
    await db.flush()
    logger.info(f"Skipped delivery {delivery.id}. Carry-forward delivery created for sub {sub.id} on {carry_date}")
    return carry_delivery


async def _complete_subscription(db: AsyncSession, subscription: Subscription) -> None:
    subscription.status = SubscriptionStatus.COMPLETED
    subscription.actual_end_date = date.today()
    logger.info(f"Subscription {subscription.id} completed after {subscription.completed_deliveries} deliveries")


async def daily_delivery_generation_job(db: AsyncSession) -> dict:
    """
    Celery Beat daily job:
    1. Generate today's delivery for all active subscriptions (if not exists)
    2. Mark yesterday's pending deliveries as MISSED
    3. Check subscriptions for completion
    """
    today = date.today()
    yesterday = today - timedelta(days=1)
    stats = {"generated": 0, "missed": 0, "completed": 0}

    # Mark yesterday's undelivered as MISSED
    missed_result = await db.execute(
        select(SubscriptionDelivery).where(
            and_(
                SubscriptionDelivery.scheduled_date == yesterday,
                SubscriptionDelivery.status.in_([DeliveryStatus.PENDING, DeliveryStatus.ASSIGNED]),
            )
        )
    )
    for delivery in missed_result.scalars().all():
        await handle_missed_delivery(db, delivery)
        stats["missed"] += 1

    # Generate today's deliveries for all active subscriptions
    active_subs = await db.execute(
        select(Subscription).where(Subscription.status == SubscriptionStatus.ACTIVE)
    )
    for sub in active_subs.scalars().all():
        existing = await db.execute(
            select(SubscriptionDelivery).where(
                and_(
                    SubscriptionDelivery.subscription_id == sub.id,
                    SubscriptionDelivery.scheduled_date == today,
                )
            )
        )
        if not existing.scalar_one_or_none():
            delivery = await _generate_next_delivery(db, sub)
            if delivery:
                stats["generated"] += 1

    await db.commit()
    logger.info(f"Daily job complete: {stats}")
    return stats
