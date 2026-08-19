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
logger = logging.getLogger(__name__)
from datetime import date, datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.models.subscription import (
    Subscription, SubscriptionStatus, SubscriptionPlan, SubscriptionItem,
    SubscriptionStatusHistory, SubscriptionPauseHistory, SubscriptionPaymentHistory
)
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus, SubscriptionDeliveryHistory
from app.models.customer import Customer
from app.models.admin_settings import AdminSettings
from app.models.payment import Payment

logger = logging.getLogger(__name__)


async def get_settings(db: AsyncSession) -> AdminSettings:
    result = await db.execute(select(AdminSettings).where(AdminSettings.id == 1))
    return result.scalar_one_or_none()


async def create_subscription(
    db: AsyncSession,
    customer: Customer,
    items_data: list,  # list of {"product": Product, "quantity": int, "package_price": float}
    plan_type: str,
    total_deliveries: int,
    plan_id: UUID | None,
    address_id: UUID,
    delivery_charge: float,
    tax_amount: float,
    preferred_delivery_time: str | None = None,
    auto_renew: bool = False,
    notes: str | None = None,
) -> Subscription:
    """Creates a subscription record with multiple items. Status remains pending_payment."""
    selected_price = 0.0
    for item in items_data:
        qty = item["quantity"]
        item_price = item["package_price"]
        selected_price += item_price * qty

    total_amount = selected_price + delivery_charge + tax_amount
    first_prod_id = items_data[0]["product"].id if items_data else None

    sub = Subscription(
        customer_id=customer.id,
        plan_id=plan_id,
        product_id=first_prod_id,
        address_id=address_id,
        status=SubscriptionStatus.PENDING_PAYMENT,
        total_deliveries=total_deliveries,
        plan_type=plan_type,
        package_price=selected_price,
        total_amount=total_amount,
        delivery_charge=delivery_charge,
        tax_amount=tax_amount,
        preferred_delivery_time=preferred_delivery_time,
        auto_renew=auto_renew,
        notes=notes,
    )
    db.add(sub)
    await db.flush()

    # Save individual items
    for item in items_data:
        prod = item["product"]
        qty = item["quantity"]
        sub_item = SubscriptionItem(
            subscription_id=sub.id,
            product_id=prod.id,
            quantity=qty,
            package_price=item["package_price"],
        )
        db.add(sub_item)

    # Status history audit log
    history = SubscriptionStatusHistory(
        subscription_id=sub.id,
        old_status="",
        new_status=SubscriptionStatus.PENDING_PAYMENT.value,
        reason="Subscription created",
    )
    db.add(history)
    await db.flush()
    return sub


async def activate_subscription(db: AsyncSession, subscription: Subscription) -> Subscription:
    """Activates subscription after payment success and generates first delivery."""
    old_status = subscription.status.value if hasattr(subscription.status, "value") else str(subscription.status)
    subscription.status = SubscriptionStatus.ACTIVE
    subscription.start_date = date.today()

    # Status history log
    history = SubscriptionStatusHistory(
        subscription_id=subscription.id,
        old_status=old_status,
        new_status=SubscriptionStatus.ACTIVE.value,
        reason="Payment successful, subscription activated"
    )
    db.add(history)

    # Capture in payment history
    result = await db.execute(
        select(Payment).where(Payment.subscription_id == subscription.id).order_by(Payment.created_at.desc()).limit(1)
    )
    last_pay = result.scalar_one_or_none()
    pay_history = SubscriptionPaymentHistory(
        subscription_id=subscription.id,
        payment_id=last_pay.id if last_pay else None,
        amount=float(subscription.total_amount) if subscription.total_amount is not None else float(last_pay.amount if last_pay and last_pay.amount is not None else 0.0),
        status="success",
        transaction_id=last_pay.gateway_payment_id if last_pay else None,
    )
    db.add(pay_history)

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

    # Audit delivery generation state
    del_history = SubscriptionDeliveryHistory(
        delivery_id=delivery.id,
        old_status="",
        new_status=DeliveryStatus.PENDING.value,
        notes="Scheduled automatically"
    )
    db.add(del_history)

    if subscription.delivery_partner_id:
        from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
        assignment = DeliveryAssignment(
            subscription_delivery_id=delivery.id,
            delivery_partner_id=subscription.delivery_partner_id,
            status=AssignmentStatus.PENDING,
            assigned_at=datetime.now(timezone.utc)
        )
        db.add(assignment)

    logger.info(f"Generated delivery for sub {subscription.id} on {next_date}")
    return delivery


async def mark_delivered(db: AsyncSession, delivery: SubscriptionDelivery) -> None:
    """Marks a delivery as DELIVERED and advances subscription counter."""
    old_status = delivery.status.value if hasattr(delivery.status, "value") else str(delivery.status)
    delivery.status = DeliveryStatus.DELIVERED
    delivery.delivered_at = datetime.now(timezone.utc)

    # Log delivery history
    del_history = SubscriptionDeliveryHistory(
        delivery_id=delivery.id,
        old_status=old_status,
        new_status=DeliveryStatus.DELIVERED.value,
        notes="Delivery marked as completed"
    )
    db.add(del_history)

    sub = await db.get(Subscription, delivery.subscription_id)
    sub.completed_deliveries += 1

    # Send push notification when delivery is completed
    try:
        from app.models.customer import Customer
        from app.models.user import User
        from app.services.notification_service import NotificationService
        
        customer = await db.get(Customer, sub.customer_id)
        if customer:
            cust_user = await db.get(User, customer.user_id)
            if cust_user:
                await NotificationService.send_notification_to_user(
                    db=db,
                    user_id=cust_user.id,
                    title="Delivery Completed",
                    body=f"Your meal has been delivered successfully at {datetime.now().strftime('%H:%M')}.",
                    notification_type="delivery",
                    reference_id=str(delivery.id)
                )
    except Exception as e:
        logger.error(f"Error sending delivery completion notification: {e}")

    remaining = sub.total_deliveries - sub.completed_deliveries
    if remaining == 2:
        try:
            from app.models.customer import Customer
            from app.models.user import User
            from app.services.notification_service import NotificationService
            
            customer = await db.get(Customer, sub.customer_id)
            if customer:
                cust_user = await db.get(User, customer.user_id)
                if cust_user:
                    await NotificationService.send_notification_to_user(
                        db=db,
                        user_id=cust_user.id,
                        title="Subscription Expiring Soon",
                        body=f"Your healthy meal subscription is expiring soon. Only {remaining} deliveries remaining. Renew now to avoid interruption!",
                        notification_type="subscription",
                        reference_id=str(sub.id)
                    )
        except Exception as e:
            logger.error(f"Error sending subscription expiry warning notification: {e}")

    if sub.completed_deliveries >= sub.total_deliveries:
        await _complete_subscription(db, sub)
    else:
        await _generate_next_delivery(db, sub)


async def handle_missed_delivery(db: AsyncSession, delivery: SubscriptionDelivery) -> None:
    """Marks delivery as MISSED and carry-forwards to next available slot."""
    old_status = delivery.status.value if hasattr(delivery.status, "value") else str(delivery.status)
    delivery.status = DeliveryStatus.MISSED

    # Log delivery history
    del_history = SubscriptionDeliveryHistory(
        delivery_id=delivery.id,
        old_status=old_status,
        new_status=DeliveryStatus.MISSED.value,
        notes="Delivery marked as missed"
    )
    db.add(del_history)

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

        # Audit carry forward generation
        del_history_cf = SubscriptionDeliveryHistory(
            delivery_id=carry_delivery.id,
            old_status="",
            new_status=DeliveryStatus.CARRY_FORWARD.value,
            notes="Carry-forward due to missed delivery"
        )
        db.add(del_history_cf)

        if sub.delivery_partner_id:
            from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
            cf_assignment = DeliveryAssignment(
                subscription_delivery_id=carry_delivery.id,
                delivery_partner_id=sub.delivery_partner_id,
                status=AssignmentStatus.PENDING,
                assigned_at=datetime.now(timezone.utc)
            )
            db.add(cf_assignment)

        logger.info(f"Carry-forward delivery created for sub {sub.id} on {carry_date}")
    await db.flush()


async def _notify_subscription_change(db: AsyncSession, subscription: Subscription, action: str, reason: str = None):
    try:
        from app.models.customer import Customer
        from app.models.user import User
        from app.models.delivery_partner import DeliveryPartner
        from app.models.delivery_assignment import DeliveryAssignment
        from app.models.subscription_delivery import SubscriptionDelivery
        from app.services.notification_service import NotificationService
        from datetime import date
        
        customer = await db.get(Customer, subscription.customer_id)
        if not customer:
            return
        cust_user = await db.get(User, customer.user_id)
        if not cust_user:
            return
            
        if action == "pause":
            cust_title = "Subscription Paused"
            cust_body = f"Your healthy meal subscription has been paused. Reason: {reason or 'Not specified'}"
            admin_title = "Customer Paused Subscription"
            admin_body = f"Customer: {cust_user.full_name} has paused their subscription."
            partner_title = "Subscription Paused"
            partner_body = f"Assigned delivery for customer {cust_user.full_name} has been paused."
        else:
            cust_title = "Subscription Resumed"
            cust_body = "Your healthy meal subscription is now active! Deliveries will resume."
            admin_title = "Customer Resumed Subscription"
            admin_body = f"Customer: {cust_user.full_name} has resumed their subscription."
            partner_title = "Subscription Resumed"
            partner_body = f"Assigned delivery for customer {cust_user.full_name} has been resumed."
            
        await NotificationService.send_notification_to_user(
            db=db,
            user_id=cust_user.id,
            title=cust_title,
            body=cust_body,
            notification_type="subscription",
            reference_id=str(subscription.id)
        )
        
        await NotificationService.send_notification_to_role(
            db=db,
            role="admin",
            title=admin_title,
            body=admin_body,
            notification_type="subscription",
            reference_id=str(subscription.id)
        )
        
        delivery_res = await db.execute(
            select(SubscriptionDelivery)
            .where(
                SubscriptionDelivery.subscription_id == subscription.id,
                SubscriptionDelivery.scheduled_date == date.today()
            )
        )
        delivery = delivery_res.scalar_one_or_none()
        if delivery:
            assign_res = await db.execute(
                select(DeliveryAssignment).where(DeliveryAssignment.subscription_delivery_id == delivery.id)
            )
            assignment = assign_res.scalar_one_or_none()
            if assignment:
                partner = await db.get(DeliveryPartner, assignment.delivery_partner_id)
                if partner:
                    await NotificationService.send_notification_to_user(
                        db=db,
                        user_id=partner.user_id,
                        title=partner_title,
                        body=partner_body,
                        notification_type="delivery",
                        reference_id=str(delivery.id)
                    )
    except Exception as e:
        logger.error(f"Error sending subscription change notification: {e}")


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

    old_status = subscription.status.value if hasattr(subscription.status, "value") else str(subscription.status)
    subscription.status = SubscriptionStatus.PAUSED
    subscription.paused_at = datetime.now(timezone.utc)
    subscription.pause_reason = reason

    # Status history log
    history = SubscriptionStatusHistory(
        subscription_id=subscription.id,
        old_status=old_status,
        new_status=SubscriptionStatus.PAUSED.value,
        reason=reason or "Subscription paused"
    )
    db.add(history)

    # Pause history log
    pause_log = SubscriptionPauseHistory(
        subscription_id=subscription.id,
        paused_at=subscription.paused_at,
        pause_reason=reason,
    )
    db.add(pause_log)

    # Cancel/skip any pending or assigned deliveries for today & future dates
    today = date.today()
    sd_res = await db.execute(
        select(SubscriptionDelivery).where(
            SubscriptionDelivery.subscription_id == subscription.id,
            SubscriptionDelivery.scheduled_date >= today,
            SubscriptionDelivery.status.in_([DeliveryStatus.PENDING, DeliveryStatus.ASSIGNED])
        )
    )
    pending_deliveries = sd_res.scalars().all()
    for sd in pending_deliveries:
        sd.status = DeliveryStatus.SKIPPED
        sd.skip_reason = reason or "Customer paused subscription today"

        # Log delivery history
        del_hist = SubscriptionDeliveryHistory(
            delivery_id=sd.id,
            old_status=sd.status.value if hasattr(sd.status, "value") else str(sd.status),
            new_status=DeliveryStatus.SKIPPED.value if hasattr(DeliveryStatus.SKIPPED, "value") else str(DeliveryStatus.SKIPPED),
            notes="Skipped due to subscription pause"
        )
        db.add(del_hist)

        # Delete/Cancel any active delivery assignment so delivery partner isn't instructed to deliver
        from app.models.delivery_assignment import DeliveryAssignment
        assignment_res = await db.execute(
            select(DeliveryAssignment).where(DeliveryAssignment.subscription_delivery_id == sd.id)
        )
        assignments = assignment_res.scalars().all()
        for assignment in assignments:
            await db.delete(assignment)

    await _notify_subscription_change(db, subscription, "pause", reason)

    return subscription


async def resume_subscription(db: AsyncSession, subscription: Subscription) -> Subscription:
    """Resume a paused subscription. Accumulates total_paused_days."""
    if subscription.status != SubscriptionStatus.PAUSED:
        raise ValueError("Subscription is not paused")

    paused_days = 0
    if subscription.paused_at:
        paused_days = (datetime.now(timezone.utc) - subscription.paused_at).days
        subscription.total_paused_days += paused_days

    old_status = subscription.status.value if hasattr(subscription.status, "value") else str(subscription.status)
    subscription.status = SubscriptionStatus.ACTIVE

    # Status history log
    history = SubscriptionStatusHistory(
        subscription_id=subscription.id,
        old_status=old_status,
        new_status=SubscriptionStatus.ACTIVE.value,
        reason="Subscription resumed"
    )
    db.add(history)

    # Update active pause history log
    pause_result = await db.execute(
        select(SubscriptionPauseHistory)
        .where(
            SubscriptionPauseHistory.subscription_id == subscription.id,
            SubscriptionPauseHistory.resumed_at == None
        )
        .order_by(SubscriptionPauseHistory.paused_at.desc())
        .limit(1)
    )
    active_pause = pause_result.scalar_one_or_none()
    if active_pause:
        active_pause.resumed_at = datetime.now(timezone.utc)
        active_pause.paused_days = paused_days

    subscription.paused_at = None
    subscription.pause_reason = None

    # Generate next delivery from today
    await _generate_next_delivery(db, subscription)
    
    await _notify_subscription_change(db, subscription, "resume")
    
    return subscription


async def cancel_subscription(db: AsyncSession, subscription: Subscription, reason: str | None = None) -> Subscription:
    """Cancel a subscription. Refund handled separately via payment service."""
    old_status = subscription.status.value if hasattr(subscription.status, "value") else str(subscription.status)
    subscription.status = SubscriptionStatus.CANCELLED
    subscription.actual_end_date = date.today()

    new_status_val = SubscriptionStatus.CANCELLED.value if hasattr(SubscriptionStatus.CANCELLED, "value") else str(SubscriptionStatus.CANCELLED)
    # Status history log
    history = SubscriptionStatusHistory(
        subscription_id=subscription.id,
        old_status=old_status,
        new_status=new_status_val,
        reason=reason or "Subscription cancelled"
    )
    db.add(history)

    # Cancel/skip any upcoming pending deliveries
    deliveries_result = await db.execute(
        select(SubscriptionDelivery).where(
            SubscriptionDelivery.subscription_id == subscription.id,
            SubscriptionDelivery.status.in_([DeliveryStatus.PENDING, DeliveryStatus.ASSIGNED])
        )
    )
    skipped_val = DeliveryStatus.SKIPPED.value if hasattr(DeliveryStatus.SKIPPED, "value") else str(DeliveryStatus.SKIPPED)
    for delivery in deliveries_result.scalars().all():
        old_del_status = delivery.status.value if hasattr(delivery.status, "value") else str(delivery.status)
        delivery.status = DeliveryStatus.SKIPPED
        
        # Log delivery history
        del_history = SubscriptionDeliveryHistory(
            delivery_id=delivery.id,
            old_status=old_del_status,
            new_status=skipped_val,
            notes="Skipped due to subscription cancellation"
        )
        db.add(del_history)

    return subscription


async def skip_delivery(db: AsyncSession, delivery: SubscriptionDelivery) -> SubscriptionDelivery:
    """Marks a delivery as SKIPPED, deletes any active delivery partner assignment,
    increments subscription pause days, and schedules a carry-forward delivery."""
    curr_status_val = delivery.status.value if hasattr(delivery.status, "value") else str(delivery.status)
    if delivery.status in [DeliveryStatus.DELIVERED, DeliveryStatus.SKIPPED, DeliveryStatus.MISSED]:
        raise ValueError(f"Cannot skip delivery in status {curr_status_val}")

    old_status = curr_status_val
    delivery.status = DeliveryStatus.SKIPPED

    skipped_val = DeliveryStatus.SKIPPED.value if hasattr(DeliveryStatus.SKIPPED, "value") else str(DeliveryStatus.SKIPPED)
    # Log delivery history
    del_history = SubscriptionDeliveryHistory(
        delivery_id=delivery.id,
        old_status=old_status,
        new_status=skipped_val,
        notes="Delivery skipped by user/admin"
    )
    db.add(del_history)

    sub = await db.get(Subscription, delivery.subscription_id)
    if not sub:
        raise ValueError("Subscription not found for this delivery")

    # Increment pause days
    sub.total_paused_days += 1

    # Remove active assignment if exists
    from app.models.delivery_assignment import DeliveryAssignment
    assignment_res = await db.execute(
        select(DeliveryAssignment).where(DeliveryAssignment.subscription_delivery_id == delivery.id)
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

    # Log CF delivery history
    del_history_cf = SubscriptionDeliveryHistory(
        delivery_id=carry_delivery.id,
        old_status="",
        new_status=DeliveryStatus.CARRY_FORWARD.value,
        notes="Carry-forward due to skipped delivery day"
    )
    db.add(del_history_cf)

    if sub.delivery_partner_id:
        from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
        cf_assignment2 = DeliveryAssignment(
            subscription_delivery_id=carry_delivery.id,
            delivery_partner_id=sub.delivery_partner_id,
            status=AssignmentStatus.PENDING,
            assigned_at=datetime.now(timezone.utc)
        )
        db.add(cf_assignment2)

    await db.flush()
    logger.info(f"Skipped delivery {delivery.id}. Carry-forward delivery created for sub {sub.id} on {carry_date}")
    return carry_delivery


async def _complete_subscription(db: AsyncSession, subscription: Subscription) -> None:
    old_status = subscription.status.value if hasattr(subscription.status, "value") else str(subscription.status)
    subscription.status = SubscriptionStatus.COMPLETED
    subscription.actual_end_date = date.today()

    # Status history log
    history = SubscriptionStatusHistory(
        subscription_id=subscription.id,
        old_status=old_status,
        new_status=SubscriptionStatus.COMPLETED.value,
        reason="Subscription completed successfully"
    )
    db.add(history)
    logger.info(f"Subscription {subscription.id} completed after {subscription.completed_deliveries} deliveries")

    # Notify Customer of completion
    try:
        from app.models.customer import Customer
        from app.models.user import User
        from app.services.notification_service import NotificationService
        
        customer = await db.get(Customer, subscription.customer_id)
        if customer:
            cust_user = await db.get(User, customer.user_id)
            if cust_user:
                await NotificationService.send_notification_to_user(
                    db=db,
                    user_id=cust_user.id,
                    title="Subscription Completed",
                    body=f"Your healthy meal subscription has completed. Total deliveries completed: {subscription.completed_deliveries}.",
                    notification_type="subscription",
                    reference_id=str(subscription.id)
                )
    except Exception as e:
        logger.error(f"Error sending subscription completion notification: {e}")


async def renew_subscription(
    db: AsyncSession,
    subscription: Subscription,
    new_plan_id: UUID | None = None,
    auto_renew: bool | None = None,
) -> Subscription:
    """Manually renews a subscription. Copies items into a new pending_payment subscription."""
    from sqlalchemy.orm import selectinload
    # Ensure items and customer are loaded
    res = await db.execute(
        select(Subscription)
        .where(Subscription.id == subscription.id)
        .options(selectinload(Subscription.items), selectinload(Subscription.customer))
    )
    sub_loaded = res.scalar_one()

    # Determine plan
    plan_id = new_plan_id or sub_loaded.plan_id
    plan_result = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id))
    plan = plan_result.scalar_one()

    # Resolve items data with product models
    items_data = []
    from app.models.product import Product
    for item in sub_loaded.items:
        prod_res = await db.execute(select(Product).where(Product.id == item.product_id))
        prod = prod_res.scalar_one()
        items_data.append({
            "product": prod,
            "quantity": item.quantity
        })

    # Generate new renewed subscription
    new_sub = await create_subscription(
        db=db,
        customer=sub_loaded.customer,
        plan=plan,
        items_data=items_data,
        address_id=sub_loaded.address_id,
        delivery_charge=float(sub_loaded.delivery_charge),
        tax_amount=float(sub_loaded.tax_amount),
        preferred_delivery_time=sub_loaded.preferred_delivery_time,
        auto_renew=auto_renew if auto_renew is not None else sub_loaded.auto_renew,
        notes=sub_loaded.notes,
    )
    return new_sub


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
