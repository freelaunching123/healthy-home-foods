import uuid
from typing import List, Optional
from sqlalchemy import String, Boolean, ForeignKey, Numeric, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class Customer(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Customer profile — one-to-one with User."""

    __tablename__ = "customers"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        unique=True, nullable=False, index=True
    )
    customer_code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="customer")
    subscriptions: Mapped[List["Subscription"]] = relationship("Subscription", back_populates="customer")
    fruit_cart_items: Mapped[List["FruitCart"]] = relationship("FruitCart", back_populates="customer", cascade="all, delete-orphan")
    fruit_orders: Mapped[List["FruitOrder"]] = relationship("FruitOrder", back_populates="customer")

    def __repr__(self) -> str:
        return f"<Customer code={self.customer_code}>"
