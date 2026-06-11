import uuid
from typing import Optional, List
from sqlalchemy import String, Boolean, ForeignKey, Numeric, Text, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class ProductCategory(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Hierarchical product categories — supports parent/child nesting."""

    __tablename__ = "product_categories"

    name: Mapped[str] = mapped_column(String(150), nullable=False)
    slug: Mapped[str] = mapped_column(String(200), unique=True, nullable=False, index=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    parent_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("product_categories.id"), nullable=True
    )
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Self-referential
    parent: Mapped[Optional["ProductCategory"]] = relationship("ProductCategory", remote_side="ProductCategory.id", back_populates="children")
    children: Mapped[List["ProductCategory"]] = relationship("ProductCategory", back_populates="parent")
    products: Mapped[List["Product"]] = relationship("Product", back_populates="category")


class Product(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Product catalog — subscribable items."""

    __tablename__ = "products"

    category_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("product_categories.id"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    slug: Mapped[str] = mapped_column(String(300), unique=True, nullable=False, index=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    short_description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    unit: Mapped[str] = mapped_column(String(50), nullable=False)  # e.g. "litre", "kg", "pcs"
    unit_size: Mapped[Optional[float]] = mapped_column(Numeric(10, 3), nullable=True)  # e.g. 0.5
    price_per_unit: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    mrp: Mapped[Optional[float]] = mapped_column(Numeric(10, 2), nullable=True)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # Relationships
    category: Mapped["ProductCategory"] = relationship("ProductCategory", back_populates="products")
    subscriptions: Mapped[List["Subscription"]] = relationship("Subscription", back_populates="product")

    def __repr__(self) -> str:
        return f"<Product name={self.name} price={self.price_per_unit}>"
