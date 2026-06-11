import uuid
from typing import Optional
from datetime import datetime
from sqlalchemy import String, ForeignKey, Numeric, DateTime, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin


class GpsTrackingLog(UUIDPrimaryKeyMixin, Base):
    """High-frequency GPS location snapshots during active deliveries."""

    __tablename__ = "gps_tracking_logs"

    assignment_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("delivery_assignments.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    delivery_boy_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("delivery_boys.id"), nullable=False, index=True
    )
    latitude: Mapped[float] = mapped_column(Numeric(10, 7), nullable=False)
    longitude: Mapped[float] = mapped_column(Numeric(10, 7), nullable=False)
    accuracy_meters: Mapped[Optional[float]] = mapped_column(Numeric(8, 2), nullable=True)
    speed_kmph: Mapped[Optional[float]] = mapped_column(Numeric(6, 2), nullable=True)
    heading: Mapped[Optional[float]] = mapped_column(Numeric(6, 2), nullable=True)   # degrees 0-360
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)

    # Relationships
    assignment: Mapped["DeliveryAssignment"] = relationship("DeliveryAssignment", back_populates="gps_logs")

    def __repr__(self) -> str:
        return f"<GpsLog lat={self.latitude} lng={self.longitude} at={self.recorded_at}>"
