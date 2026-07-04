import uuid
import enum
from typing import Optional
from datetime import datetime
from sqlalchemy import String, ForeignKey, Numeric, Text, DateTime, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class PaymentStatus(str, enum.Enum):
    PENDING = "pending"
    INITIATED = "initiated"
    SUCCESS = "success"
    FAILED = "failed"
    REFUNDED = "refunded"
    PARTIALLY_REFUNDED = "partially_refunded"


class PaymentMethod(str, enum.Enum):
    RAZORPAY = "razorpay"
    UPI = "upi"
    CARD = "card"
    NETBANKING = "netbanking"
    WALLET = "wallet"
    CASH = "cash"
    MOCK_PAYMENT = "mock_payment"


class Payment(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Payment transaction per subscription."""

    __tablename__ = "payments"

    subscription_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscriptions.id"), nullable=False, index=True
    )
    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("customers.id"), nullable=False, index=True
    )

    # Gateway data
    gateway_order_id: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    gateway_payment_id: Mapped[Optional[str]] = mapped_column(String(200), nullable=True, index=True)
    gateway_signature: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="INR", nullable=False)
    status: Mapped[PaymentStatus] = mapped_column(
        SAEnum(PaymentStatus, name="payment_status_enum", values_callable=lambda x: [e.value for e in x]),
        default=PaymentStatus.PENDING, nullable=False, index=True
    )
    payment_method: Mapped[Optional[PaymentMethod]] = mapped_column(
        SAEnum(PaymentMethod, name="payment_method_enum", values_callable=lambda x: [e.value for e in x]), nullable=True
    )
    paid_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    failure_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    refund_amount: Mapped[Optional[float]] = mapped_column(Numeric(10, 2), nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Relationships
    subscription: Mapped["Subscription"] = relationship("Subscription", back_populates="payments")
    invoice: Mapped[Optional["Invoice"]] = relationship("Invoice", back_populates="payment", uselist=False)

    def __repr__(self) -> str:
        return f"<Payment id={self.id} amount={self.amount} status={self.status}>"
