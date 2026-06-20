import uuid
import enum
from typing import Optional, List
from datetime import datetime
from sqlalchemy import String, ForeignKey, Numeric, Text, DateTime, Enum as SAEnum, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class AssignmentStatus(str, enum.Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"
    OUT_FOR_DELIVERY = "out_for_delivery"
    DELIVERED = "delivered"
    FAILED = "failed"


class DeliveryAssignment(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Links a SubscriptionDelivery to a specific delivery boy."""

    __tablename__ = "delivery_assignments"

    delivery_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscription_deliveries.id", ondelete="CASCADE"),
        unique=True, nullable=False, index=True
    )
    delivery_partner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("delivery_partners.id"), nullable=False, index=True
    )
    status: Mapped[AssignmentStatus] = mapped_column(
        SAEnum(AssignmentStatus, name="assignment_status_enum", values_callable=lambda x: [e.value for e in x]),
        default=AssignmentStatus.PENDING, nullable=False
    )

    assigned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    accepted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    picked_up_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    out_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    delivered_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    failed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    failure_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Distance & ETA
    distance_km: Mapped[Optional[float]] = mapped_column(Numeric(8, 3), nullable=True)
    estimated_minutes: Mapped[Optional[int]] = mapped_column(nullable=True)

    # Relationships
    delivery: Mapped["SubscriptionDelivery"] = relationship("SubscriptionDelivery", back_populates="assignment")
    delivery_partner: Mapped["DeliveryPartner"] = relationship("DeliveryPartner", back_populates="assignments")
    gps_logs: Mapped[List["GpsTrackingLog"]] = relationship("GpsTrackingLog", back_populates="assignment", cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<DeliveryAssignment id={self.id} status={self.status}>"


class DeliveryAssignmentHistory(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Audit log of delivery partner assignments and reassignments."""

    __tablename__ = "delivery_assignment_history"

    delivery_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscription_deliveries.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    previous_partner_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("delivery_partners.id", ondelete="SET NULL"),
        nullable=True, index=True
    )
    new_partner_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("delivery_partners.id", ondelete="SET NULL"),
        nullable=True, index=True
    )
    changed_by_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True, index=True
    )
    changed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=func.now(), nullable=False)

    # Relationships
    delivery: Mapped["SubscriptionDelivery"] = relationship("SubscriptionDelivery")
    previous_partner: Mapped[Optional["DeliveryPartner"]] = relationship("DeliveryPartner", foreign_keys=[previous_partner_id])
    new_partner: Mapped[Optional["DeliveryPartner"]] = relationship("DeliveryPartner", foreign_keys=[new_partner_id])
    changed_by: Mapped[Optional["User"]] = relationship("User")

    def __repr__(self) -> str:
        return f"<DeliveryAssignmentHistory delivery_id={self.delivery_id} prev={self.previous_partner_id} new={self.new_partner_id}>"
