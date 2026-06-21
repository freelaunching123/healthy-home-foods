import uuid
import enum
from typing import Optional
from datetime import date, datetime
from sqlalchemy import String, Boolean, ForeignKey, Numeric, Text, Integer, Date, DateTime, SmallInteger, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class DeliveryStatus(str, enum.Enum):
    PENDING = "pending"
    ASSIGNED = "assigned"
    OUT_FOR_DELIVERY = "out_for_delivery"
    DELIVERED = "delivered"
    MISSED = "missed"
    SKIPPED = "skipped"       # Customer-requested skip (counts as paused day)
    CARRY_FORWARD = "carry_forward"  # Rescheduled missed delivery


class SubscriptionDelivery(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """One record per scheduled delivery for a subscription."""

    __tablename__ = "subscription_deliveries"

    subscription_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscriptions.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    scheduled_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    status: Mapped[DeliveryStatus] = mapped_column(
        SAEnum(DeliveryStatus, name="delivery_status_enum", values_callable=lambda x: [e.value for e in x]),
        default=DeliveryStatus.PENDING, nullable=False, index=True
    )

    # Carry forward: links this record to the missed delivery it replaces
    parent_delivery_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscription_deliveries.id"), nullable=True
    )
    is_carry_forward: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Completion
    delivered_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    delivery_proof_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    customer_rating: Mapped[Optional[int]] = mapped_column(SmallInteger, nullable=True)  # 1-5
    customer_feedback: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Relationships
    subscription: Mapped["Subscription"] = relationship("Subscription", back_populates="deliveries")
    assignment: Mapped[Optional["DeliveryAssignment"]] = relationship("DeliveryAssignment", back_populates="subscription_delivery", uselist=False)
    parent_delivery: Mapped[Optional["SubscriptionDelivery"]] = relationship(
        "SubscriptionDelivery", remote_side="SubscriptionDelivery.id"
    )

    def __repr__(self) -> str:
        return f"<SubscriptionDelivery date={self.scheduled_date} status={self.status}>"
