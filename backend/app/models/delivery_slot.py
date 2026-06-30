import uuid
from datetime import date
from sqlalchemy import String, Date, Boolean
from sqlalchemy.orm import mapped_column, Mapped
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin

class DeliverySlot(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Stores available delivery dates and slots for fruit ordering."""
    
    __tablename__ = "delivery_slots"

    slot_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    time_slot: Mapped[str] = mapped_column(String(100), nullable=False)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    def __repr__(self) -> str:
        return f"<DeliverySlot date={self.slot_date} slot={self.time_slot} available={self.is_available}>"
