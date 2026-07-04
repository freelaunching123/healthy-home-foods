import uuid
import enum
from datetime import datetime, date
from typing import Optional, List
from sqlalchemy import String, Boolean, DateTime, Date, func, Enum as SAEnum, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class UserStatus(str, enum.Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"


class UserRoleEnum(str, enum.Enum):
    CUSTOMER = "customer"
    ADMIN = "admin"
    SUPER_ADMIN = "super_admin"
    DELIVERY_PARTNER = "delivery_partner"


class User(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Core identity table — shared by all user types."""

    __tablename__ = "users"

    phone: Mapped[str] = mapped_column(String(15), unique=True, nullable=False, index=True)
    email: Mapped[Optional[str]] = mapped_column(String(255), unique=True, nullable=True, index=True)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    password_hash: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    status: Mapped[UserStatus] = mapped_column(
        SAEnum(UserStatus, name="user_status_enum", values_callable=lambda x: [e.value for e in x]),
        default=UserStatus.ACTIVE,
        nullable=False,
    )
    role: Mapped[UserRoleEnum] = mapped_column(
        SAEnum(UserRoleEnum, name="user_role_enum", values_callable=lambda x: [e.value for e in x]),
        default=UserRoleEnum.CUSTOMER,
        nullable=False,
    )
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    profile_photo_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    fcm_token: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)  # Firebase push
    device_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    last_token_update: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    notification_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, server_default="true")
    last_login_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Profile details
    gender: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    dob: Mapped[Optional[date]] = mapped_column(Date, nullable=True)

    # Notification preferences
    delivery_notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    payment_notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    promotional_notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Security settings
    token_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Relationships
    customer: Mapped[Optional["Customer"]] = relationship("Customer", back_populates="user", uselist=False)
    admin: Mapped[Optional["Admin"]] = relationship("Admin", back_populates="user", uselist=False)
    delivery_partner: Mapped[Optional["DeliveryPartner"]] = relationship("DeliveryPartner", back_populates="user", uselist=False)
    addresses: Mapped[List["Address"]] = relationship("Address", back_populates="user", cascade="all, delete-orphan")
    notifications: Mapped[List["Notification"]] = relationship("Notification", back_populates="user")
    audit_logs: Mapped[List["AuditLog"]] = relationship("AuditLog", back_populates="user")

    def __repr__(self) -> str:
        return f"<User id={self.id} phone={self.phone}>"
