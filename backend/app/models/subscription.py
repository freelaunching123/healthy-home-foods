import uuid
import enum
from typing import Optional, List
from datetime import date, datetime
from sqlalchemy import String, Boolean, ForeignKey, Numeric, Text, Integer, Date, DateTime, Enum as SAEnum, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class PlanType(str, enum.Enum):
    WEEKLY = "weekly"    # 6 deliveries
    MONTHLY = "monthly"  # 26 deliveries


class SubscriptionStatus(str, enum.Enum):
    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    PENDING_PAYMENT = "pending_payment"


class SubscriptionPlan(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Plan templates — weekly (6 deliveries) or monthly (26 deliveries)."""

    __tablename__ = "subscription_plans"

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    plan_type: Mapped[PlanType] = mapped_column(SAEnum(PlanType, name="plan_type_enum", values_callable=lambda x: [e.value for e in x]), nullable=False)
    total_deliveries: Mapped[int] = mapped_column(Integer, nullable=False)  # 6 or 26
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    subscriptions: Mapped[List["Subscription"]] = relationship("Subscription", back_populates="plan")


class Subscription(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """A customer's subscription to a product plan."""

    __tablename__ = "subscriptions"

    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("customers.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    plan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscription_plans.id"), nullable=False
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id"), nullable=False, index=True
    )
    address_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("addresses.id"), nullable=False
    )
    status: Mapped[SubscriptionStatus] = mapped_column(
        SAEnum(SubscriptionStatus, name="subscription_status_enum", values_callable=lambda x: [e.value for e in x]),
        default=SubscriptionStatus.PENDING_PAYMENT, nullable=False, index=True
    )

    # Delivery tracking
    total_deliveries: Mapped[int] = mapped_column(Integer, nullable=False)   # copied from plan
    completed_deliveries: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    missed_deliveries: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # Schedule
    start_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    expected_end_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    actual_end_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)

    # Pause tracking
    paused_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    pause_reason: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    total_paused_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # Pricing snapshot (at time of purchase)
    price_per_delivery: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    total_amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    delivery_charge: Mapped[float] = mapped_column(Numeric(10, 2), default=0.0, nullable=False)
    tax_amount: Mapped[float] = mapped_column(Numeric(10, 2), default=0.0, nullable=False)

    auto_renew: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    preferred_delivery_time: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Relationships
    customer: Mapped["Customer"] = relationship("Customer", back_populates="subscriptions")
    plan: Mapped["SubscriptionPlan"] = relationship("SubscriptionPlan", back_populates="subscriptions")
    product: Mapped["Product"] = relationship("Product", back_populates="subscriptions")
    address: Mapped["Address"] = relationship("Address", back_populates="subscriptions")
    deliveries: Mapped[List["SubscriptionDelivery"]] = relationship("SubscriptionDelivery", back_populates="subscription", cascade="all, delete-orphan")
    payments: Mapped[List["Payment"]] = relationship("Payment", back_populates="subscription")

    def __repr__(self) -> str:
        return f"<Subscription id={self.id} status={self.status} done={self.completed_deliveries}/{self.total_deliveries}>"
