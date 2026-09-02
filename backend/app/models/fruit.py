import uuid
import enum
from typing import Optional, List
from datetime import datetime, date
from sqlalchemy import (
    String, Boolean, ForeignKey, Numeric, Text, Integer, Date,
    DateTime, Enum as SAEnum, CheckConstraint, UniqueConstraint, func
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


# ── Enums ─────────────────────────────────────────────────────────────────────

class FruitAvailability(str, enum.Enum):
    IN_STOCK = "in_stock"
    OUT_OF_STOCK = "out_of_stock"
    TEMPORARILY_UNAVAILABLE = "temporarily_unavailable"


class FruitOrderStatus(str, enum.Enum):
    PENDING = "pending"
    PREPARING = "preparing"
    READY = "ready"
    OUT_FOR_DELIVERY = "out_for_delivery"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"


class FruitPaymentStatus(str, enum.Enum):
    PENDING = "pending"
    INITIATED = "initiated"
    SUCCESS = "success"
    FAILED = "failed"


# ── Models ────────────────────────────────────────────────────────────────────

class Fruit(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Master catalogue of fruits available for ordering."""

    __tablename__ = "fruits"

    category_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("product_categories.id"), nullable=True, index=True
    )
    category_name: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    price_per_kg: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    unit: Mapped[str] = mapped_column(String(20), default="kg", nullable=False)
    unit_value: Mapped[Optional[str]] = mapped_column(String(50), nullable=True, default="1")
    image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    availability_status: Mapped[FruitAvailability] = mapped_column(
        SAEnum(FruitAvailability, name="fruit_availability_enum", values_callable=lambda x: [e.value for e in x]),
        default=FruitAvailability.IN_STOCK,
        nullable=False,
        index=True,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)

    __table_args__ = (
        CheckConstraint("price_per_kg > 0", name="ck_fruits_price_positive"),
    )

    # Relationships
    category: Mapped[Optional["ProductCategory"]] = relationship("ProductCategory")
    cart_items: Mapped[List["FruitCart"]] = relationship("FruitCart", back_populates="fruit")
    order_items: Mapped[List["FruitOrderItem"]] = relationship("FruitOrderItem", back_populates="fruit")

    def __repr__(self) -> str:
        return f"<Fruit name={self.name} price={self.price_per_kg} status={self.availability_status}>"


class FruitCart(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Shopping cart — one row per (customer, fruit); quantity updated in place."""

    __tablename__ = "fruit_carts"

    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("customers.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    fruit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("fruits.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    quantity_kg: Mapped[float] = mapped_column(Numeric(10, 3), nullable=False)
    unit_price: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)  # snapshot at time of add
    subtotal: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)

    __table_args__ = (
        UniqueConstraint("customer_id", "fruit_id", name="uq_fruit_cart_customer_fruit"),
        CheckConstraint("quantity_kg > 0", name="ck_fruit_cart_qty_positive"),
    )

    # Relationships
    customer: Mapped["Customer"] = relationship("Customer", back_populates="fruit_cart_items")
    fruit: Mapped["Fruit"] = relationship("Fruit", back_populates="cart_items")

    def __repr__(self) -> str:
        return f"<FruitCart customer={self.customer_id} fruit={self.fruit_id} qty={self.quantity_kg}>"


class FruitOrder(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """A placed fruit order for one customer."""

    __tablename__ = "fruit_orders"

    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("customers.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    address_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("addresses.id", ondelete="SET NULL"),
        nullable=True
    )
    order_number: Mapped[str] = mapped_column(String(50), unique=True, nullable=False, index=True)
    total_amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)

    # Payment
    payment_status: Mapped[FruitPaymentStatus] = mapped_column(
        SAEnum(FruitPaymentStatus, name="fruit_payment_status_enum", values_callable=lambda x: [e.value for e in x]),
        default=FruitPaymentStatus.PENDING, nullable=False, index=True
    )
    gateway_order_id: Mapped[Optional[str]] = mapped_column(String(200), nullable=True, index=True)
    gateway_payment_id: Mapped[Optional[str]] = mapped_column(String(200), nullable=True, index=True)
    gateway_signature: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    paid_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Delivery
    order_status: Mapped[FruitOrderStatus] = mapped_column(
        SAEnum(FruitOrderStatus, name="fruit_order_status_enum", values_callable=lambda x: [e.value for e in x]),
        default=FruitOrderStatus.PENDING, nullable=False, index=True
    )
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    delivery_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    delivery_slot: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    rating: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    review_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Relationships
    customer: Mapped["Customer"] = relationship("Customer", back_populates="fruit_orders")
    address: Mapped[Optional["Address"]] = relationship("Address", back_populates="fruit_orders")
    items: Mapped[List["FruitOrderItem"]] = relationship(
        "FruitOrderItem", back_populates="order", cascade="all, delete-orphan"
    )
    assignment: Mapped[Optional["DeliveryAssignment"]] = relationship("DeliveryAssignment", back_populates="fruit_order", uselist=False)

    def __repr__(self) -> str:
        return f"<FruitOrder order_number={self.order_number} status={self.order_status}>"


class FruitOrderItem(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Line item inside a fruit order."""

    __tablename__ = "fruit_order_items"

    order_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("fruit_orders.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    fruit_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("fruits.id", ondelete="SET NULL"),
        nullable=True, index=True
    )
    quantity_kg: Mapped[float] = mapped_column(Numeric(10, 3), nullable=False)
    price_per_kg: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)  # snapshot
    subtotal: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)

    __table_args__ = (
        CheckConstraint("quantity_kg > 0", name="ck_fruit_order_item_qty_positive"),
        CheckConstraint("price_per_kg > 0", name="ck_fruit_order_item_price_positive"),
    )

    # Relationships
    order: Mapped["FruitOrder"] = relationship("FruitOrder", back_populates="items")
    fruit: Mapped["Fruit"] = relationship("Fruit", back_populates="order_items")

    def __repr__(self) -> str:
        return f"<FruitOrderItem order={self.order_id} fruit={self.fruit_id} qty={self.quantity_kg}>"
