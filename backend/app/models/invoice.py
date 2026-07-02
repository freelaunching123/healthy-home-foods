import uuid
from typing import Optional
from sqlalchemy import String, ForeignKey, Numeric, Text, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class Invoice(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Invoice linked 1:1 to a Payment — stores all billing line items."""

    __tablename__ = "invoices"

    payment_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("payments.id", ondelete="CASCADE"),
        unique=True, nullable=False, index=True
    )
    invoice_number: Mapped[str] = mapped_column(String(50), unique=True, nullable=False, index=True)
    customer_name: Mapped[str] = mapped_column(String(255), nullable=False)
    customer_phone: Mapped[str] = mapped_column(String(15), nullable=False)
    customer_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    billing_address: Mapped[str] = mapped_column(Text, nullable=False)

    # Line items snapshot
    product_name: Mapped[str] = mapped_column(String(255), nullable=False)
    plan_name: Mapped[str] = mapped_column(String(100), nullable=False)
    total_deliveries: Mapped[int] = mapped_column(Integer, nullable=False)
    price_per_delivery: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    subtotal: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    delivery_charge: Mapped[float] = mapped_column(Numeric(10, 2), default=0.0, nullable=False)
    tax_percentage: Mapped[float] = mapped_column(Numeric(5, 2), default=0.0, nullable=False)
    tax_amount: Mapped[float] = mapped_column(Numeric(10, 2), default=0.0, nullable=False)
    total_amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="INR", nullable=False)

    pdf_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Relationships
    payment: Mapped["Payment"] = relationship("Payment", back_populates="invoice")

    def __repr__(self) -> str:
        return f"<Invoice #{self.invoice_number} total={self.total_amount}>"
