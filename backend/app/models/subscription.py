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
    plan_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscription_plans.id"), nullable=True
    )
    product_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id"), nullable=True, index=True
    )
    address_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("addresses.id"), nullable=False
    )
    status: Mapped[SubscriptionStatus] = mapped_column(
        SAEnum(SubscriptionStatus, name="subscription_status_enum", values_callable=lambda x: [e.value for e in x]),
        default=SubscriptionStatus.PENDING_PAYMENT, nullable=False, index=True
    )
    delivery_partner_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("delivery_partners.id", ondelete="SET NULL"),
        nullable=True, index=True
    )
    
    from sqlalchemy import Sequence
    order_number_seq: Mapped[Optional[int]] = mapped_column(
        Integer, Sequence("subscription_order_number_seq"), unique=True, nullable=True
    )

    @property
    def display_order_id(self) -> str:
        if not self.order_number_seq:
            return f"PKG-{str(self.id)[:8].upper()}"
        dt = self.created_at or datetime.now()
        date_str = dt.strftime("%d%m%y")
        return f"PKG-{date_str}-{self.order_number_seq:05d}"

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
    plan_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True) # weekly or monthly
    package_price: Mapped[Optional[float]] = mapped_column(Numeric(10, 2), nullable=True)
    price_per_delivery: Mapped[Optional[float]] = mapped_column(Numeric(10, 2), nullable=True) # kept for backward compatibility
    total_amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    delivery_charge: Mapped[float] = mapped_column(Numeric(10, 2), default=0.0, nullable=False)
    tax_amount: Mapped[float] = mapped_column(Numeric(10, 2), default=0.0, nullable=False)

    auto_renew: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    preferred_delivery_time: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Relationships
    customer: Mapped["Customer"] = relationship("Customer", back_populates="subscriptions")
    plan: Mapped[Optional["SubscriptionPlan"]] = relationship("SubscriptionPlan", back_populates="subscriptions")
    product: Mapped[Optional["Product"]] = relationship("Product", back_populates="subscriptions")
    address: Mapped["Address"] = relationship("Address", back_populates="subscriptions")
    delivery_partner: Mapped[Optional["DeliveryPartner"]] = relationship("DeliveryPartner")
    deliveries: Mapped[List["SubscriptionDelivery"]] = relationship("SubscriptionDelivery", back_populates="subscription", cascade="all, delete-orphan")
    payments: Mapped[List["Payment"]] = relationship("Payment", back_populates="subscription")
    
    # Multi-product items
    items: Mapped[List["SubscriptionItem"]] = relationship("SubscriptionItem", back_populates="subscription", cascade="all, delete-orphan")
    
    # History tables
    pause_history: Mapped[List["SubscriptionPauseHistory"]] = relationship("SubscriptionPauseHistory", back_populates="subscription", cascade="all, delete-orphan")
    status_history: Mapped[List["SubscriptionStatusHistory"]] = relationship("SubscriptionStatusHistory", back_populates="subscription", cascade="all, delete-orphan")
    payment_history: Mapped[List["SubscriptionPaymentHistory"]] = relationship("SubscriptionPaymentHistory", back_populates="subscription", cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<Subscription id={self.id} status={self.status} done={self.completed_deliveries}/{self.total_deliveries}>"


class SubscriptionItem(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """An individual product within a subscription."""

    __tablename__ = "subscription_items"

    subscription_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscriptions.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id"), nullable=False, index=True
    )
    quantity: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    price_per_delivery: Mapped[Optional[float]] = mapped_column(Numeric(10, 2), nullable=True)
    package_price: Mapped[Optional[float]] = mapped_column(Numeric(10, 2), nullable=True)

    subscription: Mapped["Subscription"] = relationship("Subscription", back_populates="items")
    product: Mapped["Product"] = relationship("Product")

    def __repr__(self) -> str:
        return f"<SubscriptionItem sub={self.subscription_id} product={self.product_id} qty={self.quantity}>"


class SubscriptionPauseHistory(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """History of subscription pause and resume actions."""

    __tablename__ = "subscription_pause_history"

    subscription_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscriptions.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    paused_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    resumed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    pause_reason: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    paused_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    subscription: Mapped["Subscription"] = relationship("Subscription", back_populates="pause_history")


class SubscriptionStatusHistory(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Audit trail of subscription status transitions."""

    __tablename__ = "subscription_status_history"

    subscription_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscriptions.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    old_status: Mapped[str] = mapped_column(String(50), nullable=False)
    new_status: Mapped[str] = mapped_column(String(50), nullable=False)
    changed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=func.now(), nullable=False)
    reason: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    subscription: Mapped["Subscription"] = relationship("Subscription", back_populates="status_history")


class SubscriptionPaymentHistory(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Payment transaction logging per subscription status change or capture."""

    __tablename__ = "subscription_payment_history"

    subscription_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscriptions.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    payment_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("payments.id", ondelete="SET NULL"),
        nullable=True, index=True
    )
    amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False)
    transaction_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    changed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=func.now(), nullable=False)

    subscription: Mapped["Subscription"] = relationship("Subscription", back_populates="payment_history")
    payment: Mapped[Optional["Payment"]] = relationship("Payment")

