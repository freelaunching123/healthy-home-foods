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
    IN_APP = "in_app"


class NotificationStatus(str, enum.Enum):
    PENDING = "pending"
    SENT = "sent"
    FAILED = "failed"


class NotificationCategory(str, enum.Enum):
    DELIVERY = "delivery"
    SUBSCRIPTION = "subscription"
    PAYMENT = "payment"
    PROMO = "promo"
    SYSTEM = "system"


class Notification(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Notification log for all outbound + in-app messages."""

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

    # In-app notification fields
    category: Mapped[Optional[str]] = mapped_column(String(50), nullable=True, index=True, server_default=None)
    # action_type drives navigation on the client (delivery, subscription, payment, promo, system)
    action_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True, server_default=None)
    # reference_id is the UUID of the related entity (delivery_id, payment_id, subscription_id)
    reference_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, server_default=None)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, server_default="false")
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, server_default="false")

    user: Mapped["User"] = relationship("User", back_populates="notifications")
