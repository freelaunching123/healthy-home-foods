import uuid
import enum
from typing import Optional
from datetime import datetime
from sqlalchemy import String, ForeignKey, Boolean, Integer, DateTime, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class OtpPurpose(str, enum.Enum):
    LOGIN = "login"
    REGISTER = "register"
    RESET_PASSWORD = "reset_password"
    VERIFY_PHONE = "verify_phone"


class OtpLog(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """OTP generation, attempt tracking, and expiry."""

    __tablename__ = "otp_logs"

    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True, index=True   # Nullable: OTP can be sent before user is created (registration)
    )
    phone: Mapped[str] = mapped_column(String(15), nullable=False, index=True)
    otp_code: Mapped[str] = mapped_column(String(10), nullable=False)          # hashed in production
    purpose: Mapped[OtpPurpose] = mapped_column(
        SAEnum(OtpPurpose, name="otp_purpose_enum", values_callable=lambda x: [e.value for e in x]), nullable=False
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_used: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    ip_address: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    user: Mapped[Optional["User"]] = relationship("User")
