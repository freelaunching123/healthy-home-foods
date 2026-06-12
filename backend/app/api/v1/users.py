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
