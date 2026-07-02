"""
Delivery Partner management API — separate router with /delivery-partners prefix
so it doesn't conflict with /users/{user_id} wildcard routes.
"""
from typing import Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_

from app.db.session import get_db
from app.core.dependencies import require_super_admin
from app.models.user import User
from app.core.security import hash_password
from app.schemas.common import MessageResponse

router = APIRouter(prefix="/delivery-partners", tags=["Delivery Partners"])


@router.post("", response_model=MessageResponse)
async def create_delivery_partner(
    payload: __import__('app.schemas.common', fromlist=['CreateDeliveryPartnerRequest']).CreateDeliveryPartnerRequest,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Create a new delivery partner. Super Admin only."""
    from app.models.delivery_partner import DeliveryPartner
    import shortuuid, base64, os, uuid as uuid_lib
    from app.core.config import settings

    user_result = await db.execute(select(User).where(User.phone == payload.mobile_number))
    if user_result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Phone number already registered")

    from app.models.user import UserRoleEnum

    user = User(
        phone=payload.mobile_number,
        full_name=payload.full_name,
        password_hash=hash_password(payload.password),
        is_verified=True,
        role=UserRoleEnum.DELIVERY_PARTNER,
    )
    db.add(user)
    await db.flush()

    

    photo_url = None
    if payload.photo_base64:
        try:
            header, encoded = payload.photo_base64.split(",", 1) if "," in payload.photo_base64 else ("data:image/png;base64", payload.photo_base64)
            ext = "jpg" if ("jpeg" in header or "jpg" in header) else "png"
            img_data = base64.b64decode(encoded)
            upload_dir = os.path.join(settings.UPLOAD_DIR, "profiles")
            os.makedirs(upload_dir, exist_ok=True)
            filename = f"{uuid_lib.uuid4()}.{ext}"
            with open(os.path.join(upload_dir, filename), "wb") as f:
                f.write(img_data)
            photo_url = f"/uploads/profiles/{filename}"
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid photo data")

    employee_code = f"DP{shortuuid.ShortUUID().random(length=6).upper()}"
    from app.models.delivery_partner import DeliveryPartner
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


@router.get("", response_model=list)
async def list_delivery_partners(
    search: Optional[str] = Query(None, description="Search by name or mobile"),
    is_active: Optional[bool] = Query(None, description="Filter by active status"),
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """List all delivery partners with optional search and active status filter."""
    from app.models.delivery_partner import DeliveryPartner
    from app.models.delivery_assignment import DeliveryAssignment

    query = (
        select(User, DeliveryPartner)
        .join(DeliveryPartner, DeliveryPartner.user_id == User.id)
    )

    if search:
        query = query.where(
            or_(
                User.full_name.ilike(f"%{search}%"),
                User.phone.ilike(f"%{search}%"),
            )
        )

    if is_active is not None:
        from app.models.user import UserStatus
        target = UserStatus.ACTIVE if is_active else UserStatus.INACTIVE
        query = query.where(User.status == target)

    # Filter out deleted users
    query = query.where(User.is_deleted == False)

    result = await db.execute(query)
    rows = result.all()

    partners = []
    for user, dp in rows:
        assign_result = await db.execute(
            select(func.count()).where(DeliveryAssignment.delivery_partner_id == dp.id)
        )
        partners.append({
            "id": str(dp.id),
            "user_id": str(user.id),
            "employee_code": dp.employee_code,
            "full_name": user.full_name,
            "mobile_number": user.phone,
            "age": dp.age,
            "gender": dp.gender,
            "photo_url": dp.photo_url,
            "is_active": user.status.value == "active",
            "is_available": dp.is_available,
            "total_deliveries": dp.total_deliveries,
            "assigned_count": assign_result.scalar_one(),
            "rating": float(dp.rating) if dp.rating else None,
            "created_at": user.created_at.isoformat() if user.created_at else None,
        })

    return partners


@router.get("/{partner_id}")
async def get_delivery_partner(
    partner_id: UUID,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Get full profile of a single delivery partner."""
    from app.models.delivery_partner import DeliveryPartner
    from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus

    result = await db.execute(
        select(User, DeliveryPartner)
        .join(DeliveryPartner, DeliveryPartner.user_id == User.id)
        .where(DeliveryPartner.id == partner_id)
    )
    row = result.one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Delivery partner not found")

    user, dp = row

    completed = await db.execute(
        select(func.count()).where(
            DeliveryAssignment.delivery_partner_id == dp.id,
            DeliveryAssignment.status == AssignmentStatus.DELIVERED,
        )
    )
    pending = await db.execute(
        select(func.count()).where(
            DeliveryAssignment.delivery_partner_id == dp.id,
            DeliveryAssignment.status.in_([AssignmentStatus.PENDING, AssignmentStatus.ACCEPTED, AssignmentStatus.OUT_FOR_DELIVERY]),
        )
    )

    return {
        "id": str(dp.id),
        "user_id": str(user.id),
        "employee_code": dp.employee_code,
        "full_name": user.full_name,
        "mobile_number": user.phone,
        "age": dp.age,
        "gender": dp.gender,
        "photo_url": dp.photo_url,
        "is_active": user.status.value == "active",
        "is_available": dp.is_available,
        "total_deliveries": dp.total_deliveries,
        "completed_deliveries": completed.scalar_one(),
        "pending_deliveries": pending.scalar_one(),
        "rating": float(dp.rating) if dp.rating else None,
        "created_at": user.created_at.isoformat() if user.created_at else None,
    }


@router.put("/{partner_id}", response_model=MessageResponse)
async def update_delivery_partner(
    partner_id: UUID,
    payload: dict,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update name, mobile, age, gender, and photo of a delivery partner."""
    from app.models.delivery_partner import DeliveryPartner
    import base64, os, uuid as uuid_lib
    from app.core.config import settings

    result = await db.execute(
        select(User, DeliveryPartner)
        .join(DeliveryPartner, DeliveryPartner.user_id == User.id)
        .where(DeliveryPartner.id == partner_id)
    )
    row = result.one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Delivery partner not found")

    user, dp = row

    if payload.get("full_name"):
        user.full_name = payload["full_name"]
    if payload.get("mobile_number"):
        existing = await db.execute(
            select(User).where(User.phone == payload["mobile_number"], User.id != user.id)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="Mobile number already in use")
        user.phone = payload["mobile_number"]
    if "age" in payload:
        dp.age = payload["age"]
    if "gender" in payload:
        dp.gender = payload["gender"]
    if payload.get("photo_base64"):
        try:
            photo_data = payload["photo_base64"]
            header, encoded = photo_data.split(",", 1) if "," in photo_data else ("", photo_data)
            ext = "jpg" if ("jpeg" in header or "jpg" in header) else "png"
            upload_dir = os.path.join(settings.UPLOAD_DIR, "profiles")
            os.makedirs(upload_dir, exist_ok=True)
            filename = f"{uuid_lib.uuid4()}.{ext}"
            with open(os.path.join(upload_dir, filename), "wb") as f:
                f.write(base64.b64decode(encoded))
            dp.photo_url = f"/uploads/profiles/{filename}"
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid photo data")

    await db.commit()
    return MessageResponse(message="Delivery partner updated successfully")


@router.patch("/{partner_id}/status", response_model=MessageResponse)
async def toggle_delivery_partner_status(
    partner_id: UUID,
    payload: dict,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Activate or deactivate a delivery partner account."""
    from app.models.delivery_partner import DeliveryPartner
    from app.models.user import UserStatus

    result = await db.execute(
        select(User, DeliveryPartner)
        .join(DeliveryPartner, DeliveryPartner.user_id == User.id)
        .where(DeliveryPartner.id == partner_id)
    )
    row = result.one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Delivery partner not found")

    user, dp = row
    is_active = payload.get("is_active", True)
    user.status = UserStatus.ACTIVE if is_active else UserStatus.INACTIVE
    if not is_active:
        dp.is_available = False

    await db.commit()
    return MessageResponse(message=f"Delivery partner {'activated' if is_active else 'deactivated'} successfully")


@router.patch("/{partner_id}/password", response_model=MessageResponse)
async def reset_delivery_partner_password(
    partner_id: UUID,
    payload: dict,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Reset a delivery partner's login password."""
    from app.models.delivery_partner import DeliveryPartner

    result = await db.execute(
        select(User, DeliveryPartner)
        .join(DeliveryPartner, DeliveryPartner.user_id == User.id)
        .where(DeliveryPartner.id == partner_id)
    )
    row = result.one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Delivery partner not found")

    user, _ = row
    new_password = payload.get("new_password", "")
    if len(new_password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    user.password_hash = hash_password(new_password)
    await db.commit()
    return MessageResponse(message="Password reset successfully")


@router.delete("/{partner_id}", response_model=MessageResponse)
async def delete_delivery_partner(
    partner_id: UUID,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Soft delete a delivery partner if they have no active assignments."""
    from app.models.delivery_partner import DeliveryPartner
    from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
    from app.models.user import UserStatus
    from sqlalchemy import func

    result = await db.execute(
        select(User, DeliveryPartner)
        .join(DeliveryPartner, DeliveryPartner.user_id == User.id)
        .where(DeliveryPartner.id == partner_id, User.is_deleted == False)
    )
    row = result.one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Delivery partner not found")

    user, dp = row

    # Check for active assignments
    pending_count = await db.execute(
        select(func.count()).where(
            DeliveryAssignment.delivery_partner_id == dp.id,
            DeliveryAssignment.status.in_([
                AssignmentStatus.PENDING,
                AssignmentStatus.ACCEPTED,
                AssignmentStatus.OUT_FOR_DELIVERY
            ])
        )
    )
    
    if pending_count.scalar_one() > 0:
        raise HTTPException(
            status_code=400, 
            detail="Cannot delete Delivery Partner with active assignments. Please reassign all deliveries before deletion."
        )

    # Soft delete
    user.is_deleted = True
    user.deleted_at = func.now()
    user.status = UserStatus.INACTIVE
    dp.is_available = False

    await db.commit()
    return MessageResponse(message="Delivery Partner deleted successfully")
