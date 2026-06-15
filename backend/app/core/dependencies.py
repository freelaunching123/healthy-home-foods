from typing import Optional
from uuid import UUID
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.security import decode_token
from app.db.session import get_db
from app.models.user import User
from app.models.role import UserRole, Role

bearer_scheme = HTTPBearer(auto_error=True)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Validates JWT and returns the current user."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_token(credentials.credentials)
        if payload.get("type") != "access":
            raise credentials_exception
        user_id: str = payload.get("sub")
        token_version = payload.get("version")
        if not user_id:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    result = await db.execute(select(User).where(User.id == UUID(user_id)))
    user = result.scalar_one_or_none()
    if user is None:
        raise credentials_exception
    if user.status.value != "active":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is not active")
    if token_version is not None and user.token_version != token_version:
        raise credentials_exception
    return user


async def get_current_user_roles(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[str]:
    """Returns list of role names for the current user."""
    result = await db.execute(
        select(Role.name)
        .join(UserRole, UserRole.role_id == Role.id)
        .where(UserRole.user_id == current_user.id)
    )
    return [row[0] for row in result.fetchall()]


def require_roles(*allowed_roles: str):
    """Dependency factory — raises 403 if user doesn't have any of the allowed roles."""
    async def _check(
        current_user: User = Depends(get_current_user),
        db: AsyncSession = Depends(get_db),
    ) -> User:
        result = await db.execute(
            select(Role.name)
            .join(UserRole, UserRole.role_id == Role.id)
            .where(UserRole.user_id == current_user.id)
        )
        user_roles = [row[0] for row in result.fetchall()]
        if not any(r in user_roles for r in allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required role(s): {', '.join(allowed_roles)}",
            )
        return current_user
    return _check


# ── Shorthand role dependencies ───────────────────────────────────────────────
require_super_admin = require_roles("super_admin")
require_customer = require_roles("customer", "super_admin")
require_delivery_partner = require_roles("delivery_partner", "super_admin")
require_any_authenticated = require_roles("super_admin", "customer", "delivery_partner")
