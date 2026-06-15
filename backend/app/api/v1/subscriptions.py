from uuid import UUID
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.db.session import get_db
from app.core.dependencies import get_current_user, require_customer, require_super_admin
from app.models.user import User
from app.models.customer import Customer
from app.models.subscription import Subscription, SubscriptionPlan, SubscriptionStatus
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.product import Product
from app.models.admin_settings import AdminSettings
from app.schemas.subscription import (
    SubscriptionCreate, SubscriptionPauseRequest, SubscriptionCancelRequest,
    SubscriptionResponse, SubscriptionPlanResponse, DeliveryResponse, DeliveryListResponse,
    CurrentSubscriptionResponse,
)
from app.schemas.common import MessageResponse
from app.services import subscription_engine
import math

router = APIRouter(prefix="/subscriptions", tags=["Subscriptions"])


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


@router.post("/", response_model=SubscriptionResponse)
async def create_subscription(
    payload: SubscriptionCreate,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Create a new subscription (pending payment)."""
    customer = await _get_customer(db, current_user.id)

    # Validate plan and product
    plan_result = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == payload.plan_id))
    plan = plan_result.scalar_one_or_none()
    if not plan or not plan.is_active:
        raise HTTPException(status_code=404, detail="Subscription plan not found")

    product_result = await db.execute(select(Product).where(Product.id == payload.product_id))
    product = product_result.scalar_one_or_none()
    if not product or not product.is_available:
        raise HTTPException(status_code=404, detail="Product not found or unavailable")

    # Calculate delivery charge from admin settings
    settings_result = await db.execute(select(AdminSettings).where(AdminSettings.id == 1))
    settings = settings_result.scalar_one_or_none()
    delivery_charge = 0.0
    tax_amount = 0.0
    if settings:
        tax_rate = float(settings.tax_percentage) / 100
        subtotal = float(product.price_per_unit) * plan.total_deliveries
        tax_amount = round(subtotal * tax_rate, 2)

    sub = await subscription_engine.create_subscription(
        db=db,
        customer=customer,
        plan=plan,
        product_id=payload.product_id,
        address_id=payload.address_id,
        price_per_delivery=float(product.price_per_unit),
        delivery_charge=delivery_charge,
        tax_amount=tax_amount,
        preferred_delivery_time=payload.preferred_delivery_time,
        auto_renew=payload.auto_renew,
        notes=payload.notes,
    )
    await db.commit()
    await db.refresh(sub)
    return sub


@router.get("/", response_model=list[SubscriptionResponse])
async def list_subscriptions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    status: str = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=50),
):
    customer = await _get_customer(db, current_user.id)
    query = select(Subscription).where(Subscription.customer_id == customer.id)
    if status:
        query = query.where(Subscription.status == status)
    result = await db.execute(query.offset((page - 1) * page_size).limit(page_size))
    return result.scalars().all()


@router.get("/current", response_model=CurrentSubscriptionResponse)
async def get_current_subscription(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get the customer's current active/paused (or latest) subscription with details."""
    customer = await _get_customer(db, current_user.id)
    
    # Fetch subscriptions sorted by status and date
    result = await db.execute(
        select(Subscription)
        .where(Subscription.customer_id == customer.id)
        .order_by(Subscription.created_at.desc())
    )
    subs = result.scalars().all()
    if not subs:
        raise HTTPException(status_code=404, detail="No active subscription found")
        
    # Find active or paused one first, otherwise fallback to latest
    sub = None
    for s in subs:
        if s.status in [SubscriptionStatus.ACTIVE, SubscriptionStatus.PAUSED]:
            sub = s
            break
    if not sub:
        sub = subs[0]
        
    # Load relationships to prevent greenlet/lazy load error
    from sqlalchemy.orm import selectinload
    res = await db.execute(
        select(Subscription)
        .where(Subscription.id == sub.id)
        .options(selectinload(Subscription.plan), selectinload(Subscription.product))
    )
    sub = res.scalar_one()

    # Calculate carry forward deliveries count
    carry_forward_count = await db.scalar(
        select(func.count(SubscriptionDelivery.id))
        .where(
            SubscriptionDelivery.subscription_id == sub.id,
            SubscriptionDelivery.is_carry_forward == True
        )
    )

    return CurrentSubscriptionResponse(
        id=sub.id,
        plan_name=sub.plan.name if sub.plan else "—",
        plan_type=sub.plan.plan_type.value if sub.plan and hasattr(sub.plan.plan_type, "value") else (sub.plan.plan_type if sub.plan else "—"),
        start_date=sub.start_date,
        status=sub.status.value if hasattr(sub.status, "value") else sub.status,
        total_deliveries=sub.total_deliveries,
        completed_deliveries=sub.completed_deliveries,
        remaining_deliveries=max(0, sub.total_deliveries - sub.completed_deliveries),
        paused_days=sub.total_paused_days,
        missed_deliveries=sub.missed_deliveries,
        carry_forward_deliveries=carry_forward_count or 0,
        product_name=sub.product.name if sub.product else "—",
        price_per_delivery=float(sub.price_per_delivery),
        total_amount=float(sub.total_amount),
    )


@router.get("/{sub_id}", response_model=SubscriptionResponse)
async def get_subscription(
    sub_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    customer = await _get_customer(db, current_user.id)
    return await _get_subscription_for_customer(db, sub_id, customer.id)


@router.post("/{sub_id}/pause", response_model=MessageResponse)
async def pause_subscription(
    sub_id: UUID,
    payload: SubscriptionPauseRequest,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    customer = await _get_customer(db, current_user.id)
    sub = await _get_subscription_for_customer(db, sub_id, customer.id)
    try:
        await subscription_engine.pause_subscription(db, sub, payload.reason)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    await db.commit()
    return MessageResponse(message="Subscription paused successfully")


@router.post("/{sub_id}/resume", response_model=MessageResponse)
async def resume_subscription(
    sub_id: UUID,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    customer = await _get_customer(db, current_user.id)
    sub = await _get_subscription_for_customer(db, sub_id, customer.id)
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
    customer = await _get_customer(db, current_user.id)
    sub = await _get_subscription_for_customer(db, sub_id, customer.id)
    await subscription_engine.cancel_subscription(db, sub)
    await db.commit()
    return MessageResponse(message="Subscription cancelled successfully")


@router.get("/{sub_id}/deliveries", response_model=DeliveryListResponse)
async def get_subscription_deliveries(
    sub_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: str = Query(None),
):
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
    """Skip/Pause a specific delivery day (customer or admin requested). Triggers carry-forward extension."""
    # Check user role
    from app.models.role import Role, UserRole
    roles_res = await db.execute(
        select(Role.name)
        .join(UserRole, UserRole.role_id == Role.id)
        .where(UserRole.user_id == current_user.id)
    )
    user_roles = [r[0] for r in roles_res.fetchall()]
    is_admin = "super_admin" in user_roles

    # Fetch the delivery
    delivery_result = await db.execute(
        select(SubscriptionDelivery).where(SubscriptionDelivery.id == delivery_id)
    )
    delivery = delivery_result.scalar_one_or_none()
    if not delivery:
        raise HTTPException(status_code=404, detail="Delivery not found")

    sub = await db.get(Subscription, delivery.subscription_id)
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    # Verify ownership if not admin
    if not is_admin:
        customer = await _get_customer(db, current_user.id)
        if sub.customer_id != customer.id:
            raise HTTPException(status_code=403, detail="Not authorized to skip this delivery")

    # Enforce status rules: only pending or assigned deliveries can be skipped
    if delivery.status not in [DeliveryStatus.PENDING, DeliveryStatus.ASSIGNED]:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot skip a delivery that is {delivery.status.value}"
        )

    try:
        await subscription_engine.skip_delivery(db, delivery)
        await db.commit()
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return MessageResponse(message="Delivery day skipped and extended successfully")
