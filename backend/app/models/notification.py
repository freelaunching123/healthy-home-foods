import uuid
import enum
from typing import Optional
from sqlalchemy import String, ForeignKey, Boolean, Text, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class NotificationChannel(str, enum.Enum):
    SMS = "sms"
    EMAIL = "email"
    PUSH = "push"


class NotificationStatus(str, enum.Enum):
    PENDING = "pending"
    SENT = "sent"
    FAILED = "failed"


class Notification(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Notification log for all outbound messages."""

    __tablename__ = "notifications"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    channel: Mapped[NotificationChannel] = mapped_column(
        SAEnum(NotificationChannel, name="notification_channel_enum", values_callable=lambda x: [e.value for e in x]), nullable=False
    )
    event_type: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    title: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[NotificationStatus] = mapped_column(
        SAEnum(NotificationStatus, name="notification_status_enum", values_callable=lambda x: [e.value for e in x]),
        default=NotificationStatus.PENDING, nullable=False
    )
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # JSON string

    user: Mapped["User"] = relationship("User", back_populates="notifications")
