import uuid
import enum
from typing import Optional, List
from sqlalchemy import String, Boolean, ForeignKey, Numeric, Text, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class AddressType(str, enum.Enum):
    HOME = "home"
    WORK = "work"
    OTHER = "other"


class Address(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Delivery address — multiple per user, one marked as default."""

    __tablename__ = "addresses"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    label: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)  # e.g. "Home", "Mom's House"
    address_type: Mapped[AddressType] = mapped_column(
        SAEnum(AddressType, name="address_type_enum", values_callable=lambda x: [e.value for e in x]),
        default=AddressType.HOME, nullable=False
    )
    address_line1: Mapped[str] = mapped_column(String(500), nullable=False)
    address_line2: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    city: Mapped[str] = mapped_column(String(100), nullable=False)
    state: Mapped[str] = mapped_column(String(100), nullable=False)
    pincode: Mapped[str] = mapped_column(String(10), nullable=False, index=True)
    landmark: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    latitude: Mapped[Optional[float]] = mapped_column(Numeric(10, 7), nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Numeric(10, 7), nullable=True)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="addresses")
    subscriptions: Mapped[List["Subscription"]] = relationship("Subscription", back_populates="address")
    fruit_orders: Mapped[List["FruitOrder"]] = relationship("FruitOrder", back_populates="address")

    def __repr__(self) -> str:
        return f"<Address id={self.id} pincode={self.pincode}>"
