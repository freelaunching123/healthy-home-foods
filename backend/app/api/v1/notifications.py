"""
Notifications API — In-app notification management for customers, admins, and delivery partners.

Endpoints:
  GET    /notifications              — paginated list with category/read filters
  GET    /notifications/unread-count — unread badge count
  PATCH  /notifications/{id}/read    — mark single notification as read
  PATCH  /notifications/read-all     — mark all as read for current user
  POST   /notifications/fcm-token    — register/update user FCM token
  DELETE /notifications/clear-all    — soft-delete all notifications
  DELETE /notifications/{id}         — soft-delete a notification
"""
import uuid as uuid_lib
from uuid import UUID
from typing import Optional
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func
from pydantic import BaseModel

from app.db.session import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.notification_history import NotificationHistory
from app.services.notification_service import NotificationService

router = APIRouter(prefix="/notifications", tags=["Notifications"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class NotificationResponse(BaseModel):
    id: UUID
    title: Optional[str]
    body: str
    category: Optional[str]
    action_type: Optional[str]
    reference_id: Optional[str]
    event_type: str
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class UnreadCountResponse(BaseModel):
    count: int


class MessageResponse(BaseModel):
    message: str
    success: bool = True


class FCMTokenUpdate(BaseModel):
    fcm_token: str
    device_type: Optional[str] = None


# ── Helpers ───────────────────────────────────────────────────────────────────

def _base_query(user_id: UUID):
    """Base query: user's non-deleted notifications ordered newest first."""
    return (
        select(NotificationHistory)
        .where(
            NotificationHistory.user_id == user_id,
            NotificationHistory.is_deleted == False,
        )
        .order_by(NotificationHistory.created_at.desc())
    )


# ── Routes ────────────────────────────────────────────────────────────────────

@router.get("", response_model=list[NotificationResponse])
async def list_notifications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    category: Optional[str] = Query(None, description="Filter by category: delivery|subscription|payment|system"),
    is_read: Optional[bool] = Query(None, description="Filter by read state"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """List notifications for the authenticated user."""
    query = _base_query(current_user.id)

    if category:
        query = query.where(NotificationHistory.notification_type == category)
    if is_read is not None:
        query = query.where(NotificationHistory.is_read == is_read)

    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/unread-count", response_model=UnreadCountResponse)
async def get_unread_count(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the number of unread notifications."""
    count = await db.scalar(
        select(func.count(NotificationHistory.id))
        .where(
            NotificationHistory.user_id == current_user.id,
            NotificationHistory.is_deleted == False,
            NotificationHistory.is_read == False,
        )
    )
    return UnreadCountResponse(count=count or 0)


@router.patch("/{notification_id}/read", response_model=MessageResponse)
async def mark_as_read(
    notification_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mark a single notification as read."""
    result = await db.execute(
        select(NotificationHistory).where(
            NotificationHistory.id == notification_id,
            NotificationHistory.user_id == current_user.id,
            NotificationHistory.is_deleted == False,
        )
    )
    notification = result.scalar_one_or_none()
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")

    notification.is_read = True
    notification.read_at = datetime.now(timezone.utc)
    await db.commit()
    return MessageResponse(message="Notification marked as read")


@router.patch("/read-all", response_model=MessageResponse)
async def mark_all_read(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mark all unread notifications as read for the current user."""
    await db.execute(
        update(NotificationHistory)
        .where(
            NotificationHistory.user_id == current_user.id,
            NotificationHistory.is_read == False,
            NotificationHistory.is_deleted == False,
        )
        .values(is_read=True, read_at=datetime.now(timezone.utc))
    )
    await db.commit()
    return MessageResponse(message="All notifications marked as read")


@router.post("/fcm-token", response_model=MessageResponse)
async def update_fcm_token_route(
    payload: FCMTokenUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Register or update the User's FCM token."""
    await NotificationService.update_fcm_token(
        db=db,
        user_id=current_user.id,
        fcm_token=payload.fcm_token,
        device_type=payload.device_type,
    )
    return MessageResponse(message="FCM token updated successfully")


@router.delete("/clear-all", response_model=MessageResponse)
async def clear_all_notifications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete all notifications for the current user."""
    await db.execute(
        update(NotificationHistory)
        .where(
            NotificationHistory.user_id == current_user.id,
            NotificationHistory.is_deleted == False,
        )
        .values(is_deleted=True)
    )
    await db.commit()
    return MessageResponse(message="All notifications cleared")


@router.delete("/{notification_id}", response_model=MessageResponse)
async def delete_notification(
    notification_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete a notification (hides from the user without removing from DB)."""
    result = await db.execute(
        select(NotificationHistory).where(
            NotificationHistory.id == notification_id,
            NotificationHistory.user_id == current_user.id,
        )
    )
    notification = result.scalar_one_or_none()
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")

    notification.is_deleted = True
    await db.commit()
    return MessageResponse(message="Notification deleted")
