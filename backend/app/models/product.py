import uuid
import enum
from typing import Optional, List
from sqlalchemy import String, Boolean, ForeignKey, Numeric, Text, Integer, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class ProductStatus(str, enum.Enum):
    DRAFT = "draft"
    PUBLISHED = "published"
    HIDDEN = "hidden"


class ProductAvailability(str, enum.Enum):
    AVAILABLE = "available"
    OUT_OF_STOCK = "out_of_stock"
    TEMPORARILY_UNAVAILABLE = "temporarily_unavailable"


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
    image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    price: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    discount_price: Mapped[Optional[float]] = mapped_column(Numeric(10, 2), nullable=True)
    
    status: Mapped[ProductStatus] = mapped_column(
        SAEnum(ProductStatus, name="product_status_enum", values_callable=lambda x: [e.value for e in x]),
        default=ProductStatus.DRAFT, nullable=False, index=True
    )
    availability: Mapped[ProductAvailability] = mapped_column(
        SAEnum(ProductAvailability, name="product_availability_enum", values_callable=lambda x: [e.value for e in x]),
        default=ProductAvailability.AVAILABLE, nullable=False
    )
    display_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_popular: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_today_special: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Relationships
    category: Mapped["ProductCategory"] = relationship("ProductCategory", back_populates="products")
    subscriptions: Mapped[List["Subscription"]] = relationship("Subscription", back_populates="product")

    def __repr__(self) -> str:
        return f"<Product name={self.name} price={self.price}>"
