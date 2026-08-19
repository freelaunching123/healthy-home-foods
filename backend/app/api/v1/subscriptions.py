from uuid import UUID
from datetime import date
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_, and_
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.core.dependencies import get_current_user, require_customer, require_super_admin
from app.models.user import User
from app.models.customer import Customer
from app.models.subscription import Subscription, SubscriptionPlan, SubscriptionStatus, SubscriptionItem, SubscriptionStatusHistory, SubscriptionPauseHistory, SubscriptionPaymentHistory
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.product import Product
from app.models.admin_settings import AdminSettings
from app.schemas.subscription import (
    SubscriptionCreate, SubscriptionUpdate, SubscriptionPauseRequest, SubscriptionCancelRequest,
    SubscriptionResponse, SubscriptionDetailResponse, SubscriptionPlanResponse, DeliveryResponse, DeliveryListResponse,
    CurrentSubscriptionResponse, TodayDeliveryInfo,
)
from app.schemas.common import MessageResponse
from app.services import subscription_engine
from app.services.notification_service import NotificationService
from app.models.address import Address
from app.services.delivery_engine import haversine
import math

router = APIRouter(prefix="/subscriptions", tags=["Subscriptions"])


def _is_admin(user: User) -> bool:
    if not user or not user.role:
        return False
    role_val = user.role.value if hasattr(user.role, "value") else str(user.role)
    return role_val in ["admin", "super_admin"]


async def _get_customer(db: AsyncSession, user_id: UUID) -> Customer:
    result = await db.execute(select(Customer).where(Customer.user_id == user_id))
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer profile not found")
    return customer


async def _get_subscription_for_customer(
    db: AsyncSession, sub_id: UUID, customer_id: UUID
) -> Subscription:
    result = await db.execute(
        select(Subscription).where(
            Subscription.id == sub_id,
            Subscription.customer_id == customer_id,
        )
    )
    sub = result.scalar_one_or_none()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    return sub


@router.get("/plans", response_model=list[SubscriptionPlanResponse])
async def list_plans(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.is_active == True))
    return result.scalars().all()


@router.get("/dashboard/stats")
async def get_subscription_dashboard_stats(
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Get subscription metrics for admin dashboard."""
    active = await db.scalar(select(func.count(Subscription.id)).where(Subscription.status == SubscriptionStatus.ACTIVE))
    paused = await db.scalar(select(func.count(Subscription.id)).where(Subscription.status == SubscriptionStatus.PAUSED))
    completed = await db.scalar(select(func.count(Subscription.id)).where(Subscription.status == SubscriptionStatus.COMPLETED))
    cancelled = await db.scalar(select(func.count(Subscription.id)).where(Subscription.status == SubscriptionStatus.CANCELLED))
    pending = await db.scalar(select(func.count(Subscription.id)).where(Subscription.status == SubscriptionStatus.PENDING_PAYMENT))

    # Total revenue from payments
    from app.models.payment import Payment, PaymentStatus
    total_rev = await db.scalar(select(func.coalesce(func.sum(Payment.amount), 0)).where(Payment.status == PaymentStatus.SUCCESS))

    today = date.today()
    first_of_month = date(today.year, today.month, 1)
    new_subs = await db.scalar(select(func.count(Subscription.id)).where(Subscription.created_at >= first_of_month))

    return {
        "active": active or 0,
        "paused": paused or 0,
        "completed": completed or 0,
        "cancelled": cancelled or 0,
        "pending_payment": pending or 0,
        "total_revenue": float(total_rev or 0),
        "new_subscriptions_this_month": new_subs or 0,
    }


@router.post("", response_model=SubscriptionResponse)
async def create_subscription(
    payload: SubscriptionCreate,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Create a new multi-product subscription (pending payment)."""
    customer = await _get_customer(db, current_user.id)

    if not payload.items:
        raise HTTPException(status_code=400, detail="Subscription must contain at least one product")

    # Validate products & compile items_data
    items_data = []
    selected_price = 0.0
    first_plan_type = None
    first_package_days = None

    for item in payload.items:
        prod_result = await db.execute(select(Product).where(Product.id == item.product_id))
        product = prod_result.scalar_one_or_none()
        if not product or not product.is_active:
            raise HTTPException(status_code=404, detail=f"Product {item.product_id} not found or inactive")
        
        if first_plan_type is None:
            first_plan_type = product.plan_type
            first_package_days = product.package_days
        elif first_plan_type != product.plan_type:
            raise HTTPException(status_code=400, detail="All products in a subscription must have the same plan type")
            
        item_price = float(product.discount_price if product.discount_price else product.package_price)
        
        items_data.append({"product": product, "quantity": item.quantity, "package_price": item_price})
        selected_price += item_price * item.quantity

    # Validate address
    addr_result = await db.execute(
        select(Address).where(Address.id == payload.address_id, Address.user_id == current_user.id)
    )
    address = addr_result.scalar_one_or_none()
    if not address:
        raise HTTPException(status_code=404, detail="Address not found")

    # Calculate delivery charge and tax from admin settings
    settings_result = await db.execute(select(AdminSettings).where(AdminSettings.id == 1))
    settings = settings_result.scalar_one_or_none()
    delivery_charge = 0.0
    tax_amount = 0.0
    
    if settings:
        distance = 0.0
        if address.latitude and address.longitude:
            shop_lat = float(settings.business_lat) if settings.business_lat is not None else 9.919630
            shop_lng = float(settings.business_lng) if settings.business_lng is not None else 78.094379
            distance = haversine(
                shop_lat, shop_lng,
                float(address.latitude), float(address.longitude)
            )
        max_dist = float(getattr(settings, "max_delivery_distance_km", 15.0))
        if distance > max_dist:
            raise HTTPException(
                status_code=400,
                detail=f"There is no service beyond {max_dist}km. Please select an address within the range."
            )
            
        from app.services.delivery_engine import calculate_charge_for_distance
        charge_per_delivery = calculate_charge_for_distance(distance, settings)
        delivery_charge = first_package_days * charge_per_delivery
        
        tax_rate = float(settings.tax_percentage) / 100
        tax_amount = round(selected_price * tax_rate, 2)

    sub = await subscription_engine.create_subscription(
        db=db,
        customer=customer,
        items_data=items_data,
        plan_type=first_plan_type,
        total_deliveries=first_package_days,
        plan_id=payload.plan_id,
        address_id=payload.address_id,
        delivery_charge=delivery_charge,
        tax_amount=tax_amount,
        preferred_delivery_time=payload.preferred_delivery_time,
        auto_renew=payload.auto_renew,
        notes=payload.notes,
    )
    await db.commit()

    # Load with items and products
    result = await db.execute(
        select(Subscription)
        .where(Subscription.id == sub.id)
        .options(
            selectinload(Subscription.items).selectinload(SubscriptionItem.product),
            selectinload(Subscription.customer).selectinload(Customer.user),
            selectinload(Subscription.plan)
        )
    )
    sub_loaded = result.scalar_one()
    if sub_loaded.customer and sub_loaded.customer.user:
        sub_loaded.customer_name = sub_loaded.customer.user.full_name
        sub_loaded.customer_phone = sub_loaded.customer.user.phone
    if sub_loaded.plan:
        sub_loaded.plan_name = sub_loaded.plan.name
    for item in sub_loaded.items:
        item.product_name = item.product.name

    return sub_loaded


@router.put("/{sub_id}", response_model=SubscriptionResponse)
async def update_subscription(
    sub_id: UUID,
    payload: SubscriptionUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update subscription options and items."""
    is_admin = _is_admin(current_user)

    result = await db.execute(
        select(Subscription)
        .where(Subscription.id == sub_id)
        .options(selectinload(Subscription.items))
    )
    sub = result.scalar_one_or_none()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    if not is_admin:
        customer = await _get_customer(db, current_user.id)
        if sub.customer_id != customer.id:
            raise HTTPException(status_code=403, detail="Not authorized to edit this subscription")

    # Update items if provided
    if payload.items is not None:
        # Delete existing items
        for existing in sub.items:
            await db.delete(existing)
        sub.items.clear()

        package_price = 0.0
        first_plan_type = None
        for item in payload.items:
            p_res = await db.execute(select(Product).where(Product.id == item.product_id))
            prod = p_res.scalar_one_or_none()
            if not prod or not prod.is_active:
                raise HTTPException(status_code=404, detail=f"Product {item.product_id} not found or inactive")
                
            if first_plan_type is None:
                first_plan_type = prod.plan_type
            elif first_plan_type != prod.plan_type:
                raise HTTPException(status_code=400, detail="All products in a subscription must have the same plan type")
            
            item_price = float(prod.discount_price if prod.discount_price else prod.package_price)
            
            sub_item = SubscriptionItem(
                subscription_id=sub.id,
                product_id=prod.id,
                quantity=item.quantity,
                package_price=item_price
            )
            db.add(sub_item)
            package_price += item_price * item.quantity

        sub.package_price = package_price
        sub.plan_type = first_plan_type
        
        # Recalculate totals
        settings_result = await db.execute(select(AdminSettings).where(AdminSettings.id == 1))
        settings = settings_result.scalar_one_or_none()
        tax_rate = float(settings.tax_percentage) / 100 if settings else 0.0
        subtotal = package_price
        sub.tax_amount = round(subtotal * tax_rate, 2)
        sub.total_amount = subtotal + float(sub.delivery_charge) + sub.tax_amount

    # Update other parameters
    if payload.address_id is not None:
        sub.address_id = payload.address_id
    if payload.preferred_delivery_time is not None:
        sub.preferred_delivery_time = payload.preferred_delivery_time
    if payload.auto_renew is not None:
        sub.auto_renew = payload.auto_renew
    if payload.notes is not None:
        sub.notes = payload.notes

    # Add change logging
    history = SubscriptionStatusHistory(
        subscription_id=sub.id,
        old_status=sub.status.value,
        new_status=sub.status.value,
        reason="Subscription items or configurations updated"
    )
    db.add(history)

    await db.commit()

    # Reload with products
    result = await db.execute(
        select(Subscription)
        .where(Subscription.id == sub.id)
        .options(
            selectinload(Subscription.items).selectinload(SubscriptionItem.product),
            selectinload(Subscription.customer).selectinload(Customer.user),
            selectinload(Subscription.plan)
        )
    )
    sub_loaded = result.scalar_one()
    if sub_loaded.customer and sub_loaded.customer.user:
        sub_loaded.customer_name = sub_loaded.customer.user.full_name
        sub_loaded.customer_phone = sub_loaded.customer.user.phone
    if sub_loaded.plan:
        sub_loaded.plan_name = sub_loaded.plan.name
    for item in sub_loaded.items:
        item.product_name = item.product.name
    return sub_loaded


@router.delete("/{sub_id}", response_model=MessageResponse)
async def delete_subscription(
    sub_id: UUID,
    current_user: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Delete a subscription permanently."""
    result = await db.execute(select(Subscription).where(Subscription.id == sub_id))
    sub = result.scalar_one_or_none()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    await db.delete(sub)
    await db.commit()
    return MessageResponse(message="Subscription permanently deleted")


@router.get("", response_model=list[SubscriptionResponse])
async def list_subscriptions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    status: str = Query(None),
    customer_id: Optional[UUID] = Query(None),
    search: str = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=50),
):
    """List subscriptions with search, filtering and sorting."""
    is_admin = _is_admin(current_user)

    query = select(Subscription).options(
        selectinload(Subscription.items).selectinload(SubscriptionItem.product),
        selectinload(Subscription.customer).selectinload(Customer.user),
        selectinload(Subscription.plan)
    )

    if not is_admin:
        customer = await _get_customer(db, current_user.id)
        query = query.where(Subscription.customer_id == customer.id)
    elif customer_id:
        query = query.where(Subscription.customer_id == customer_id)

    if status and status != "all":
        query = query.where(Subscription.status == status)

    if search:
        from app.models.user import User as UserModel
        from app.models.product import Product as ProductModel
        
        query = (
            query.join(Customer, Customer.id == Subscription.customer_id)
            .join(UserModel, UserModel.id == Customer.user_id)
            .outerjoin(SubscriptionItem, SubscriptionItem.subscription_id == Subscription.id)
            .outerjoin(ProductModel, ProductModel.id == SubscriptionItem.product_id)
            .where(
                or_(
                    UserModel.full_name.ilike(f"%{search}%"),
                    UserModel.phone.ilike(f"%{search}%"),
                    ProductModel.name.ilike(f"%{search}%"),
                )
            )
            .distinct()
        )

    # Sort descending
    query = query.order_by(Subscription.created_at.desc())

    result = await db.execute(query.offset((page - 1) * page_size).limit(page_size))
    subs = result.scalars().all()

    # Map fields
    for sub in subs:
        if sub.customer and sub.customer.user:
            sub.customer_name = sub.customer.user.full_name
            sub.customer_phone = sub.customer.user.phone
        if sub.plan:
            sub.plan_name = sub.plan.name
        for item in sub.items:
            item.product_name = item.product.name

    return subs


@router.get("/current", response_model=CurrentSubscriptionResponse)
async def get_current_subscription(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get the customer's current active/paused subscription with all details."""
    customer = await _get_customer(db, current_user.id)
    
    result = await db.execute(
        select(Subscription)
        .where(Subscription.customer_id == customer.id)
        .order_by(Subscription.created_at.desc())
    )
    subs = result.scalars().all()
    if not subs:
        raise HTTPException(status_code=404, detail="No active subscription found")
        
    sub = None
    for s in subs:
        if s.status in [SubscriptionStatus.ACTIVE, SubscriptionStatus.PAUSED]:
            sub = s
            break
    if not sub:
        sub = subs[0]
        
    res = await db.execute(
        select(Subscription)
        .where(Subscription.id == sub.id)
        .options(selectinload(Subscription.plan), selectinload(Subscription.items).selectinload(SubscriptionItem.product))
    )
    sub = res.scalar_one()

    # Product name resolution
    product_name = "—"
    if sub.product and sub.product.name:
        product_name = sub.product.name
    elif sub.items:
        prod_names = [item.product.name for item in sub.items if item.product]
        if len(prod_names) == 1:
            product_name = prod_names[0]
        elif len(prod_names) > 1:
            product_name = f"{prod_names[0]} + {len(prod_names) - 1} other(s)"

    carry_forward_count = await db.scalar(
        select(func.count(SubscriptionDelivery.id))
        .where(
            SubscriptionDelivery.subscription_id == sub.id,
            SubscriptionDelivery.is_carry_forward == True
        )
    )

    today = date.today()
    next_delivery_result = await db.execute(
        select(SubscriptionDelivery.scheduled_date)
        .where(
            SubscriptionDelivery.subscription_id == sub.id,
            SubscriptionDelivery.status == DeliveryStatus.PENDING,
            SubscriptionDelivery.scheduled_date >= today,
        )
        .order_by(SubscriptionDelivery.scheduled_date.asc())
        .limit(1)
    )
    next_delivery_date = next_delivery_result.scalar_one_or_none()

    today_delivery_info = None
    today_delivery_result = await db.execute(
        select(SubscriptionDelivery)
        .where(
            SubscriptionDelivery.subscription_id == sub.id,
            SubscriptionDelivery.scheduled_date == today,
        )
        .limit(1)
    )
    today_delivery = today_delivery_result.scalar_one_or_none()
    if today_delivery:
        partner_name = None
        partner_phone = None
        estimated_minutes = None
        from app.models.delivery_assignment import DeliveryAssignment
        from app.models.delivery_partner import DeliveryPartner
        from app.models.user import User as UserModel
        assignment_result = await db.execute(
            select(DeliveryAssignment)
            .where(DeliveryAssignment.subscription_delivery_id == today_delivery.id)
        )
        assignment = assignment_result.scalar_one_or_none()
        if assignment:
            estimated_minutes = assignment.estimated_minutes
            dp_result = await db.execute(
                select(DeliveryPartner).where(DeliveryPartner.id == assignment.delivery_partner_id)
            )
            dp = dp_result.scalar_one_or_none()
            if dp:
                dp_user_result = await db.execute(
                    select(UserModel).where(UserModel.id == dp.user_id)
                )
                dp_user = dp_user_result.scalar_one_or_none()
                partner_name = dp_user.full_name if dp_user else None
                partner_phone = dp_user.phone if dp_user else None

        from app.core.order_utils import format_subscription_order_id
        today_sub_ord_id = format_subscription_order_id(
            scheduled_date=today_delivery.scheduled_date,
            preferred_time=sub.preferred_delivery_time,
            delivery_id=today_delivery.id
        )

        today_delivery_info = TodayDeliveryInfo(
            delivery_id=str(today_delivery.id),
            order_id=today_sub_ord_id,
            status=today_delivery.status.value if hasattr(today_delivery.status, "value") else str(today_delivery.status),
            partner_name=partner_name,
            partner_phone=partner_phone,
            estimated_minutes=estimated_minutes,
        )

    return CurrentSubscriptionResponse(
        id=sub.id,
        plan_name=sub.plan.name if sub.plan else "—",
        plan_type=sub.plan.plan_type.value if sub.plan and hasattr(sub.plan.plan_type, "value") else (sub.plan.plan_type if sub.plan else "—"),
        start_date=sub.start_date,
        expected_end_date=sub.expected_end_date,
        status=sub.status.value if hasattr(sub.status, "value") else sub.status,
        total_deliveries=sub.total_deliveries,
        completed_deliveries=sub.completed_deliveries,
        remaining_deliveries=max(0, sub.total_deliveries - sub.completed_deliveries),
        paused_days=sub.total_paused_days,
        missed_deliveries=sub.missed_deliveries,
        carry_forward_deliveries=carry_forward_count or 0,
        product_name=product_name,
        price_per_delivery=float(sub.price_per_delivery) if sub.price_per_delivery is not None else 0.0,
        total_amount=float(sub.total_amount),
        next_delivery_date=next_delivery_date,
        today_delivery=today_delivery_info,
    )


@router.get("/{sub_id}", response_model=SubscriptionDetailResponse)
async def get_subscription(
    sub_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get rich subscription detail including history log lists."""
    is_admin = _is_admin(current_user)

    query = (
        select(Subscription)
        .where(Subscription.id == sub_id)
        .options(
            selectinload(Subscription.items).selectinload(SubscriptionItem.product),
            selectinload(Subscription.customer).selectinload(Customer.user),
            selectinload(Subscription.plan),
            selectinload(Subscription.status_history),
            selectinload(Subscription.pause_history),
            selectinload(Subscription.payment_history),
        )
    )
    result = await db.execute(query)
    sub = result.scalar_one_or_none()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    if not is_admin:
        customer = await _get_customer(db, current_user.id)
        if sub.customer_id != customer.id:
            raise HTTPException(status_code=403, detail="Not authorized to view this subscription")

    if sub.customer and sub.customer.user:
        sub.customer_name = sub.customer.user.full_name
        sub.customer_phone = sub.customer.user.phone
    if sub.plan:
        sub.plan_name = sub.plan.name
    for item in sub.items:
        item.product_name = item.product.name

    return sub


@router.post("/{sub_id}/pause", response_model=MessageResponse)
async def pause_subscription(
    sub_id: UUID,
    payload: SubscriptionPauseRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Pause an active subscription."""
    is_admin = _is_admin(current_user)

    sub_res = await db.execute(select(Subscription).where(Subscription.id == sub_id))
    sub = sub_res.scalar_one_or_none()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    if not is_admin:
        customer = await _get_customer(db, current_user.id)
        if sub.customer_id != customer.id:
            raise HTTPException(status_code=403, detail="Not authorized to pause this subscription")

    try:
        await subscription_engine.pause_subscription(db, sub, payload.reason)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    await db.commit()
    return MessageResponse(message="Subscription paused successfully")


@router.post("/{sub_id}/resume", response_model=MessageResponse)
async def resume_subscription(
    sub_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Resume a paused subscription."""
    is_admin = _is_admin(current_user)

    sub_res = await db.execute(select(Subscription).where(Subscription.id == sub_id))
    sub = sub_res.scalar_one_or_none()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    if not is_admin:
        customer = await _get_customer(db, current_user.id)
        if sub.customer_id != customer.id:
            raise HTTPException(status_code=403, detail="Not authorized to resume this subscription")

    try:
        await subscription_engine.resume_subscription(db, sub)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
        
    await db.commit()
    return MessageResponse(message="Subscription resumed successfully")


@router.post("/{sub_id}/cancel", response_model=MessageResponse)
async def cancel_subscription(
    sub_id: UUID,
    payload: SubscriptionCancelRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cancel a subscription."""
    is_admin = _is_admin(current_user)

    sub_res = await db.execute(select(Subscription).where(Subscription.id == sub_id))
    sub = sub_res.scalar_one_or_none()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    if not is_admin:
        customer = await _get_customer(db, current_user.id)
        if sub.customer_id != customer.id:
            raise HTTPException(status_code=403, detail="Not authorized to cancel this subscription")

    try:
        await subscription_engine.cancel_subscription(db, sub, payload.reason)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Send Notification
    customer_profile = await db.get(Customer, sub.customer_id)
    if customer_profile:
        await NotificationService.send_notification_to_user(
            db=db,
            user_id=customer_profile.user_id,
            title="Subscription Cancelled",
            body=f"Your subscription has been cancelled. Reason: {payload.reason or 'User cancelled'}",
            notification_type="subscription",
            reference_id=str(sub.id)
        )

    await db.commit()
    return MessageResponse(message="Subscription cancelled successfully")


@router.post("/{sub_id}/renew", response_model=SubscriptionResponse)
async def renew_subscription(
    sub_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    new_plan_id: Optional[UUID] = Query(None),
    auto_renew: Optional[bool] = Query(None),
):
    """Renew a subscription manually."""
    is_admin = _is_admin(current_user)

    sub_res = await db.execute(select(Subscription).where(Subscription.id == sub_id))
    sub = sub_res.scalar_one_or_none()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    if not is_admin:
        customer = await _get_customer(db, current_user.id)
        if sub.customer_id != customer.id:
            raise HTTPException(status_code=403, detail="Not authorized to renew this subscription")

    try:
        renewed_sub = await subscription_engine.renew_subscription(
            db=db,
            subscription=sub,
            new_plan_id=new_plan_id,
            auto_renew=auto_renew,
        )
        await db.commit()
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

    # Reload with products
    result = await db.execute(
        select(Subscription)
        .where(Subscription.id == renewed_sub.id)
        .options(
            selectinload(Subscription.items).selectinload(SubscriptionItem.product),
            selectinload(Subscription.customer).selectinload(Customer.user),
            selectinload(Subscription.plan)
        )
    )
    sub_loaded = result.scalar_one()
    if sub_loaded.customer and sub_loaded.customer.user:
        sub_loaded.customer_name = sub_loaded.customer.user.full_name
        sub_loaded.customer_phone = sub_loaded.customer.user.phone
    if sub_loaded.plan:
        sub_loaded.plan_name = sub_loaded.plan.name
    for item in sub_loaded.items:
        item.product_name = item.product.name
    return sub_loaded


@router.get("/{sub_id}/deliveries", response_model=DeliveryListResponse)
async def get_subscription_deliveries(
    sub_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: str = Query(None),
):
    is_admin = _is_admin(current_user)

    if not is_admin:
        customer = await _get_customer(db, current_user.id)
        await _get_subscription_for_customer(db, sub_id, customer.id)

    query = select(SubscriptionDelivery).where(SubscriptionDelivery.subscription_id == sub_id)
    if status:
        query = query.where(SubscriptionDelivery.status == status)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.order_by(SubscriptionDelivery.scheduled_date.desc())
        .offset((page - 1) * page_size).limit(page_size)
    )
    return DeliveryListResponse(
        total=total, page=page, page_size=page_size, items=result.scalars().all()
    )


@router.post("/deliveries/{delivery_id}/skip", response_model=MessageResponse)
async def skip_delivery_endpoint(
    delivery_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Skip a specific delivery day. Triggers carry-forward extension and registers skipped status history."""
    is_admin = _is_admin(current_user)

    delivery_result = await db.execute(
        select(SubscriptionDelivery).where(SubscriptionDelivery.id == delivery_id)
    )
    delivery = delivery_result.scalar_one_or_none()
    if not delivery:
        raise HTTPException(status_code=404, detail="Delivery not found")
        
    del_status_val = delivery.status.value if hasattr(delivery.status, "value") else str(delivery.status)

    sub = await db.get(Subscription, delivery.subscription_id)
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    if not is_admin:
        customer = await _get_customer(db, current_user.id)
        if sub.customer_id != customer.id:
            raise HTTPException(status_code=403, detail="Not authorized to skip this delivery")

    if delivery.status not in [DeliveryStatus.PENDING, DeliveryStatus.ASSIGNED]:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot skip a delivery that is {del_status_val}"
        )

    try:
        await subscription_engine.skip_delivery(db, delivery)
        await db.commit()
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return MessageResponse(message="Delivery day skipped and extended successfully")
