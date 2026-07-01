import uuid
from sqlalchemy import ForeignKey, Numeric, Integer, UniqueConstraint, CheckConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin

class PackageCart(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Shopping cart for packages — one row per (customer, product)."""

    __tablename__ = "package_carts"

    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("customers.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    quantity: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    unit_price: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    subtotal: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)

    __table_args__ = (
        UniqueConstraint("customer_id", "product_id", name="uq_package_cart_customer_product"),
        CheckConstraint("quantity > 0", name="ck_package_cart_qty_positive"),
    )

    # Relationships
    customer: Mapped["Customer"] = relationship("Customer", back_populates="package_cart_items", foreign_keys=[customer_id])
    product: Mapped["Product"] = relationship("Product", foreign_keys=[product_id])
