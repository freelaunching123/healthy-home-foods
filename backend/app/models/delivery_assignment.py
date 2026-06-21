import uuid
import enum
from typing import Optional, List
from datetime import datetime
from sqlalchemy import String, ForeignKey, Numeric, Text, DateTime, Enum as SAEnum
import sqlalchemy
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class AssignmentStatus(str, enum.Enum):
    PENDING = "pending"
    PICKED_UP = "picked_up"
    OUT_FOR_DELIVERY = "out_for_delivery"
    DELIVERED = "delivered"
    FAILED = "failed"


class DeliveryAssignment(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Links a SubscriptionDelivery to a specific delivery boy."""

    __tablename__ = "delivery_assignments"

    subscription_delivery_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscription_deliveries.id", ondelete="CASCADE"),
        nullable=True, index=True
    )
    fruit_order_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("fruit_orders.id", ondelete="CASCADE"),
        nullable=True, index=True
    )
    delivery_partner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("delivery_partners.id"), nullable=False, index=True
    )
    status: Mapped[AssignmentStatus] = mapped_column(
        SAEnum(AssignmentStatus, name="assignment_status_enum", values_callable=lambda x: [e.value for e in x]),
        default=AssignmentStatus.PENDING, nullable=False
    )

    assigned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    picked_up_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    out_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    delivered_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    failed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    failure_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    __table_args__ = (
        # Ensure exactly one order reference is provided
        sqlalchemy.CheckConstraint(
            "(subscription_delivery_id IS NOT NULL AND fruit_order_id IS NULL) OR "
            "(subscription_delivery_id IS NULL AND fruit_order_id IS NOT NULL)",
            name="ck_delivery_assignments_single_order"
        ),
    )

    # Distance & ETA
    distance_km: Mapped[Optional[float]] = mapped_column(Numeric(8, 3), nullable=True)
    estimated_minutes: Mapped[Optional[int]] = mapped_column(nullable=True)

    # Relationships
    subscription_delivery: Mapped[Optional["SubscriptionDelivery"]] = relationship("SubscriptionDelivery", back_populates="assignment")
    fruit_order: Mapped[Optional["FruitOrder"]] = relationship("FruitOrder", back_populates="assignment")
    delivery_partner: Mapped["DeliveryPartner"] = relationship("DeliveryPartner", back_populates="assignments")
    gps_logs: Mapped[List["GpsTrackingLog"]] = relationship("GpsTrackingLog", back_populates="assignment", cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<DeliveryAssignment id={self.id} status={self.status}>"
