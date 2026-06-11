import uuid
import enum
from typing import Optional, List
from sqlalchemy import String, Boolean, ForeignKey, Numeric, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class VehicleType(str, enum.Enum):
    BICYCLE = "bicycle"
    MOTORCYCLE = "motorcycle"
    CAR = "car"
    VAN = "van"


class DeliveryBoy(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Delivery boy profile — one-to-one with User."""

    __tablename__ = "delivery_boys"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        unique=True, nullable=False, index=True
    )
    employee_code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    vehicle_type: Mapped[Optional[VehicleType]] = mapped_column(
        SAEnum(VehicleType, name="vehicle_type_enum", values_callable=lambda x: [e.value for e in x]), nullable=True
    )
    vehicle_number: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    license_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    service_zone: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    current_lat: Mapped[Optional[float]] = mapped_column(Numeric(10, 7), nullable=True)
    current_lng: Mapped[Optional[float]] = mapped_column(Numeric(10, 7), nullable=True)
    total_deliveries: Mapped[int] = mapped_column(default=0, nullable=False)
    rating: Mapped[Optional[float]] = mapped_column(Numeric(3, 2), nullable=True)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="delivery_boy")
    assignments: Mapped[List["DeliveryAssignment"]] = relationship("DeliveryAssignment", back_populates="delivery_boy")

    def __repr__(self) -> str:
        return f"<DeliveryBoy code={self.employee_code}>"
