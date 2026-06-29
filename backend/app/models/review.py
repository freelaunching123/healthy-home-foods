"""
Review model for customer ratings of Products and Fruits.
"""
import uuid
import enum
from typing import Optional
from datetime import datetime
from sqlalchemy import (
    String, Boolean, ForeignKey, Integer, Text,
    DateTime, Enum as SAEnum, CheckConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class ReviewItemType(str, enum.Enum):
    PRODUCT = "product"
    FRUIT = "fruit"


class Review(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Customer review for a Product or Fruit."""

    __tablename__ = "reviews"

    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("customers.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    item_type: Mapped[ReviewItemType] = mapped_column(
        SAEnum(ReviewItemType, name="review_item_type_enum", values_callable=lambda x: [e.value for e in x]),
        nullable=False, index=True
    )
    item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False, index=True
    )
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    review_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_visible: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    __table_args__ = (
        CheckConstraint("rating >= 1 AND rating <= 5", name="ck_reviews_rating_range"),
    )

    # Relationship to customer
    customer: Mapped["Customer"] = relationship("Customer", back_populates="reviews")

    def __repr__(self) -> str:
        return f"<Review item_type={self.item_type} item_id={self.item_id} rating={self.rating}>"
