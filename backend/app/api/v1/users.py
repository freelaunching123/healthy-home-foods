from typing import Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_

from app.db.session import get_db
from app.core.dependencies import get_current_user, require_super_admin
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate, UserResponse, UserListResponse
from app.schemas.common import MessageResponse
from app.core.security import hash_password

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Get current authenticated user profile."""
    return current_user


@router.put("/me", response_model=UserResponse)
async def update_me(
    payload: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update current user's profile."""
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(current_user, field, value)
    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.get("/", response_model=UserListResponse)
async def list_users(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: str = Query(None),
    role: str = Query(None),
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """List all users — Super Admin only. Supports search and pagination."""
    query = select(User)
    
    if role == "customer":
        from app.models.customer import Customer
        query = query.join(Customer, Customer.user_id == User.id)
    elif role == "delivery_partner":
        from app.models.delivery_partner import DeliveryPartner
        query = query.join(DeliveryPartner, DeliveryPartner.user_id == User.id)
    elif role:
        from app.models.role import Role, UserRole
        query = (
            query.join(UserRole, UserRole.user_id == User.id)
            .join(Role, Role.id == UserRole.role_id)
            .where(Role.name == role)
        )

    if search:
        query = query.where(
            or_(
                User.full_name.ilike(f"%{search}%"),
                User.phone.ilike(f"%{search}%"),
                User.email.ilike(f"%{search}%"),
            )
        )
    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    users = result.scalars().all()

    return UserListResponse(total=total, page=page, page_size=page_size, items=users)


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: UUID,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.put("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: UUID,
    payload: UserUpdate,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return user


@router.delete("/{user_id}", response_model=MessageResponse)
async def deactivate_user(
    user_id: UUID,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.status = "inactive"
    await db.commit()
    return MessageResponse(message="User deactivated successfully")


@router.post("/delivery-partners", response_model=MessageResponse)
async def create_delivery_partner(
    payload: __import__('app.schemas.common', fromlist=['CreateDeliveryPartnerRequest']).CreateDeliveryPartnerRequest,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    from app.models.delivery_partner import DeliveryPartner
    from app.models.role import Role, UserRole
    import shortuuid
    import base64
    import os
    from app.core.config import settings
    import uuid

    # Check if user already exists
    user_result = await db.execute(select(User).where(User.phone == payload.mobile_number))
    if user_result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Phone number already registered")

    user = User(
        phone=payload.mobile_number,
        full_name=payload.full_name,
        password_hash=hash_password(payload.password),
        is_verified=True,
    )
    db.add(user)
    await db.flush()

    # Assign role
    role_result = await db.execute(select(Role).where(Role.name == "delivery_partner"))
    role = role_result.scalar_one_or_none()
    if role:
        db.add(UserRole(user_id=user.id, role_id=role.id))

    # Save photo if provided
    photo_url = None
    if payload.photo_base64:
        try:
            # Assumes format: data:image/png;base64,iVBORw0KGgo...
            header, encoded = payload.photo_base64.split(",", 1) if "," in payload.photo_base64 else ("data:image/png;base64", payload.photo_base64)
            ext = "png"
            if "jpeg" in header or "jpg" in header:
                ext = "jpg"
            img_data = base64.b64decode(encoded)
            upload_dir = os.path.join(settings.UPLOAD_DIR, "profiles")
            os.makedirs(upload_dir, exist_ok=True)
            filename = f"{uuid.uuid4()}.{ext}"
            filepath = os.path.join(upload_dir, filename)
            with open(filepath, "wb") as f:
                f.write(img_data)
            photo_url = f"/uploads/profiles/{filename}"
        except Exception as e:
            raise HTTPException(status_code=400, detail="Invalid photo data")

    employee_code = f"DP{shortuuid.ShortUUID().random(length=6).upper()}"
    dp = DeliveryPartner(
        user_id=user.id,
        employee_code=employee_code,
        age=payload.age,
        gender=payload.gender,
        photo_url=photo_url,
    )
    db.add(dp)
    await db.commit()

    return MessageResponse(message="Delivery partner created successfully")


@router.get("/customers/{user_id}/detail")
async def get_customer_detail(
    user_id: UUID,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Get complete profile details of a customer (addresses, subscriptions, payments, deliveries)."""
    # Fetch user
    user_result = await db.execute(select(User).where(User.id == user_id))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Fetch customer
    from app.models.customer import Customer
    customer_result = await db.execute(select(Customer).where(Customer.user_id == user_id))
    customer = customer_result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer profile not found for this user")

    # Fetch addresses
    from app.models.address import Address
    addresses_result = await db.execute(select(Address).where(Address.user_id == user_id))
    addresses = addresses_result.scalars().all()

    # Fetch subscriptions
    from app.models.subscription import Subscription
    from sqlalchemy.orm import selectinload
    subscriptions_result = await db.execute(
        select(Subscription)
        .where(Subscription.customer_id == customer.id)
        .options(selectinload(Subscription.plan), selectinload(Subscription.product))
        .order_by(Subscription.created_at.desc())
    )
    subscriptions = subscriptions_result.scalars().all()

    # Fetch payments
    from app.models.payment import Payment
    payments_result = await db.execute(
        select(Payment)
        .where(Payment.customer_id == customer.id)
        .order_by(Payment.created_at.desc())
    )
    payments = payments_result.scalars().all()

    # Fetch deliveries
    from app.models.subscription_delivery import SubscriptionDelivery
    from app.models.delivery_assignment import DeliveryAssignment
    from app.models.delivery_partner import DeliveryPartner
    deliveries_result = await db.execute(
        select(SubscriptionDelivery)
        .join(Subscription, Subscription.id == SubscriptionDelivery.subscription_id)
        .where(Subscription.customer_id == customer.id)
        .options(
            selectinload(SubscriptionDelivery.assignment)
            .selectinload(DeliveryAssignment.delivery_partner)
            .selectinload(DeliveryPartner.user)
        )
        .order_by(SubscriptionDelivery.scheduled_date.desc())
    )
    deliveries = deliveries_result.scalars().all()

    # Format response
    formatted_addresses = [{
        "id": str(addr.id),
        "label": addr.label,
        "address_type": addr.address_type.value if hasattr(addr.address_type, "value") else addr.address_type,
        "address_line1": addr.address_line1,
        "address_line2": addr.address_line2,
        "city": addr.city,
        "state": addr.state,
        "pincode": addr.pincode,
        "is_default": addr.is_default
    } for addr in addresses]

    formatted_subscriptions = [{
        "id": str(sub.id),
        "plan_name": sub.plan.name if sub.plan else "—",
        "product_name": sub.product.name if sub.product else "—",
        "status": sub.status.value if hasattr(sub.status, "value") else sub.status,
        "total_deliveries": sub.total_deliveries,
        "completed_deliveries": sub.completed_deliveries,
        "missed_deliveries": sub.missed_deliveries,
        "start_date": sub.start_date.isoformat() if sub.start_date else None,
        "expected_end_date": sub.expected_end_date.isoformat() if sub.expected_end_date else None,
        "total_amount": float(sub.total_amount),
        "paused_at": sub.paused_at.isoformat() if sub.paused_at else None,
        "pause_reason": sub.pause_reason,
        "total_paused_days": sub.total_paused_days
    } for sub in subscriptions]

    formatted_payments = [{
        "id": str(p.id),
        "subscription_id": str(p.subscription_id),
        "amount": float(p.amount),
        "status": p.status.value if hasattr(p.status, "value") else p.status,
        "paid_at": p.paid_at.isoformat() if p.paid_at else None,
        "payment_method": p.payment_method.value if p.payment_method and hasattr(p.payment_method, "value") else (p.payment_method or "—"),
        "gateway_payment_id": p.gateway_payment_id
    } for p in payments]

    formatted_deliveries = []
    for d in deliveries:
        assigned_partner = None
        if d.assignment and d.assignment.delivery_partner and d.assignment.delivery_partner.user:
            partner_user = d.assignment.delivery_partner.user
            assigned_partner = {
                "id": str(d.assignment.delivery_partner.id),
                "full_name": partner_user.full_name,
                "mobile_number": partner_user.phone
            }

        formatted_deliveries.append({
            "id": str(d.id),
            "subscription_id": str(d.subscription_id),
            "scheduled_date": d.scheduled_date.isoformat() if d.scheduled_date else None,
            "status": d.status.value if hasattr(d.status, "value") else d.status,
            "delivered_at": d.delivered_at.isoformat() if d.delivered_at else None,
            "delivery_proof_url": d.delivery_proof_url,
            "customer_rating": d.customer_rating,
            "customer_feedback": d.customer_feedback,
            "assigned_partner": assigned_partner
        })

    return {
        "user": {
            "id": str(user.id),
            "full_name": user.full_name,
            "phone": user.phone,
            "email": user.email,
            "status": user.status.value if hasattr(user.status, "value") else user.status,
            "created_at": user.created_at.isoformat() if user.created_at else None
        },
        "customer": {
            "id": str(customer.id),
            "customer_code": customer.customer_code,
            "is_active": customer.is_active
        },
        "addresses": formatted_addresses,
        "subscriptions": formatted_subscriptions,
        "payments": formatted_payments,
        "deliveries": formatted_deliveries
    }



