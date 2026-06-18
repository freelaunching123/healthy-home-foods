"""
Notifications API — In-app notification management for customers.

Endpoints:
  GET    /notifications              — paginated list with category/read filters
  GET    /notifications/unread-count — unread badge count
  PATCH  /notifications/{id}/read    — mark single notification as read
  PATCH  /notifications/read-all     — mark all as read for current user
  DELETE /notifications/{id}         — soft-delete a notification
"""
import uuid as uuid_lib
from uuid import UUID
from typing import Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func
from pydantic import BaseModel

from app.db.session import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.notification import Notification

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


# ── Helpers ───────────────────────────────────────────────────────────────────

def _base_query(user_id: UUID):
    """Base query: user's non-deleted in-app notifications ordered newest first."""
    return (
        select(Notification)
        .where(
            Notification.user_id == user_id,
            Notification.is_deleted == False,
            Notification.channel == "in_app",
        )
        .order_by(Notification.created_at.desc())
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
    """List in-app notifications for the authenticated user."""
    query = _base_query(current_user.id)

    if category:
        query = query.where(Notification.category == category)
    if is_read is not None:
        query = query.where(Notification.is_read == is_read)

    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/unread-count", response_model=UnreadCountResponse)
async def get_unread_count(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the number of unread in-app notifications."""
    count = await db.scalar(
        select(func.count(Notification.id))
        .where(
            Notification.user_id == current_user.id,
            Notification.is_deleted == False,
            Notification.channel == "in_app",
            Notification.is_read == False,
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
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == current_user.id,
            Notification.is_deleted == False,
        )
    )
    notification = result.scalar_one_or_none()
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")

    notification.is_read = True
    await db.commit()
    return MessageResponse(message="Notification marked as read")


@router.patch("/read-all", response_model=MessageResponse)
async def mark_all_read(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mark all unread notifications as read for the current user."""
    await db.execute(
        update(Notification)
        .where(
            Notification.user_id == current_user.id,
            Notification.is_read == False,
            Notification.is_deleted == False,
            Notification.channel == "in_app",
        )
        .values(is_read=True)
    )
    await db.commit()
    return MessageResponse(message="All notifications marked as read")


@router.delete("/{notification_id}", response_model=MessageResponse)
async def delete_notification(
    notification_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete a notification (hides from the user without removing from DB)."""
    result = await db.execute(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == current_user.id,
        )
    )
    notification = result.scalar_one_or_none()
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")

    notification.is_deleted = True
    await db.commit()
    return MessageResponse(message="Notification deleted")
