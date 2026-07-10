from datetime import datetime, timedelta, timezone
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.db.session import get_db
from app.core.security import create_access_token, create_refresh_token, decode_token, verify_password, hash_password, validate_password_strength
from app.core.config import settings
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.customer import Customer
from app.models.customer import Customer
from app.schemas.auth import (
    AdminLoginRequest, TokenResponse, RefreshTokenRequest,
    RegisterRequest, RegisterResponse, LoginPasswordRequest, ForgotPasswordRequest
)
from app.schemas.common import MessageResponse
from app.services.notification_service import NotificationService
import shortuuid
import logging

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register", response_model=RegisterResponse)
async def register_customer(
    payload: RegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    """Register a new customer account."""
    if payload.mobile_number == "9876543210":
        raise HTTPException(status_code=400, detail="This number is reserved and cannot be registered.")

    if not payload.password:
        raise HTTPException(status_code=400, detail="Password is required")

    if not validate_password_strength(payload.password):
        raise HTTPException(
            status_code=400,
            detail="Password must be 8-32 characters and contain at least one uppercase letter, one lowercase letter, one number, and one special character."
        )

    # Check if user exists
    user_result = await db.execute(select(User).where(User.phone == payload.mobile_number))
    if user_result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Phone number already registered")
        
    user = User(
        phone=payload.mobile_number,
        full_name=payload.full_name,
        password_hash=hash_password(payload.password) if payload.password else None,
        is_verified=True,
    )
    db.add(user)
    await db.flush()

    # Role is already set to CUSTOMER by default in the model

    customer_code = f"C{shortuuid.ShortUUID().random(length=8).upper()}"
    db.add(Customer(user_id=user.id, customer_code=customer_code))
    await db.commit()
    
    # Send welcome notification to customer
    try:
        await NotificationService.send_notification_to_user(
            db=db,
            user_id=user.id,
            title="Welcome to Healthy Home Foods",
            body="Your account has been created successfully.",
            notification_type="promo"
        )
    except Exception as e:
        logger.error(f"Failed to send welcome notification: {e}")
    
    # Notify admin
    try:
        await NotificationService.send_notification_to_role(
            db=db,
            role="admin",
            title="New Customer Registered",
            body=f"Customer Name: {user.full_name}",
            notification_type="system",
            reference_id=str(user.id)
        )
    except Exception as e:
        logger.error(f"Failed to send admin notification: {e}")
    
    return RegisterResponse(message="Registration successful", user_id=str(user.id))


@router.post("/login", response_model=TokenResponse)
async def admin_login(
    payload: AdminLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """Email or Mobile Number + password login."""
    if payload.email:
        result = await db.execute(select(User).where(User.email == payload.email))
    elif payload.mobile_number:
        phone_val = payload.mobile_number.strip().lstrip("+")
        if phone_val.startswith("91") and len(phone_val) == 12:
            phone_val = phone_val[2:]
        result = await db.execute(select(User).where(User.phone == phone_val))
    else:
        raise HTTPException(status_code=400, detail="Email or mobile number is required")

    user = result.scalar_one_or_none()

    if not user or not user.password_hash:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if getattr(user, 'is_deleted', False):
        raise HTTPException(status_code=403, detail="Account is deleted")
    if user.status.value != "active":
        raise HTTPException(status_code=403, detail="Account is suspended")

    user_role = user.role.value



    user.last_login_at = datetime.now(timezone.utc)
    await db.commit()

    token_data = {"sub": str(user.id), "role": user_role, "version": user.token_version}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        user_id=str(user.id),
        role=user_role,
        full_name=user.full_name,
    )


@router.post("/login-password", response_model=TokenResponse)
async def login_with_password(
    payload: LoginPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    """Phone + password login (for admin / pre-registered users)."""
    result = await db.execute(select(User).where(User.phone == payload.phone))
    user = result.scalar_one_or_none()

    if not user or not user.password_hash:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if getattr(user, 'is_deleted', False):
        raise HTTPException(status_code=403, detail="Account is deleted")
    if user.status.value != "active":
        raise HTTPException(status_code=403, detail="Account is suspended")

    user_role = user.role.value

    user.last_login_at = datetime.now(timezone.utc)
    await db.commit()

    token_data = {"sub": str(user.id), "role": user_role, "version": user.token_version}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        user_id=str(user.id),
        role=user_role,
        full_name=user.full_name,
    )


@router.post("/logout", response_model=MessageResponse)
async def logout(current_user: User = Depends(get_current_user)):
    """Logout current user (client-side token deletion expected)."""
    return MessageResponse(message="Logged out successfully")



@router.post("/refresh-token", response_model=TokenResponse)
async def refresh_token(
    payload: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """Issue new access token using a valid refresh token."""
    from jose import JWTError
    try:
        data = decode_token(payload.refresh_token)
        if data.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Invalid refresh token")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    user_id = data.get("sub")
    result = await db.execute(select(User).where(User.id == UUID(user_id)))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    if getattr(user, 'is_deleted', False):
        raise HTTPException(status_code=403, detail="Account is deleted")

    user_role = user.role.value
    token_data = {"sub": str(user.id), "role": user_role, "version": user.token_version}

    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        user_id=str(user.id),
        role=user_role,
        full_name=user.full_name,
    )


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(
    payload: ForgotPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    """Reset password directly without OTP verification."""
    result = await db.execute(select(User).where(User.phone == payload.mobile_number))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User with this phone number not found")
        
    if not validate_password_strength(payload.new_password):
        raise HTTPException(
            status_code=400,
            detail="Password must be 8-32 characters and contain at least one uppercase letter, one lowercase letter, one number, and one special character."
        )

    user.password_hash = hash_password(payload.new_password)
    await db.commit()
    return MessageResponse(message="Password updated successfully")
