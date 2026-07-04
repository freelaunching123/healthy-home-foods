from typing import Optional
from datetime import time
from sqlalchemy import String, Boolean, Numeric, Text, Time, Integer
from sqlalchemy.orm import mapped_column, Mapped
from app.db.base import Base
from app.db.mixins import TimestampMixin


class AdminSettings(TimestampMixin, Base):
    """
    Global singleton settings table — ID is always 1.
    All business-configurable values live here, none hardcoded.
    """

    __tablename__ = "admin_settings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)

    # Delivery charges
    free_delivery_radius_km: Mapped[float] = mapped_column(Numeric(5, 2), default=5.0, nullable=False)
    delivery_charge_per_km: Mapped[float] = mapped_column(Numeric(8, 2), default=10.0, nullable=False)
    delivery_charge_0_to_5_km: Mapped[float] = mapped_column(Numeric(8, 2), default=0.0, nullable=False)
    delivery_charge_5_to_10_km: Mapped[float] = mapped_column(Numeric(8, 2), default=15.0, nullable=False)
    delivery_charge_10_to_15_km: Mapped[float] = mapped_column(Numeric(8, 2), default=25.0, nullable=False)
    max_delivery_distance_km: Mapped[float] = mapped_column(Numeric(5, 2), default=15.0, nullable=False)

    # Business info
    business_name: Mapped[str] = mapped_column(String(255), default="Healthy Home Foods", nullable=False)
    business_address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    business_lat: Mapped[Optional[float]] = mapped_column(Numeric(10, 7), nullable=True)
    business_lng: Mapped[Optional[float]] = mapped_column(Numeric(10, 7), nullable=True)
    business_phone: Mapped[Optional[str]] = mapped_column(String(15), nullable=True)
    business_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Working hours
    working_hours_start: Mapped[Optional[time]] = mapped_column(Time, nullable=True)
    working_hours_end: Mapped[Optional[time]] = mapped_column(Time, nullable=True)

    # OTP provider
    otp_provider: Mapped[str] = mapped_column(String(50), default="msg91", nullable=False)
    otp_api_key: Mapped[Optional[str]] = mapped_column(Text, nullable=True)      # encrypted
    otp_template_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    otp_sender_id: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # Notification settings
    notification_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    sms_notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    email_notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    push_notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    delivery_boy_reminder_time: Mapped[Optional[time]] = mapped_column(Time, default=time(7, 0), nullable=True)

    # Maps & GPS
    maps_provider: Mapped[str] = mapped_column(String(50), default="google", nullable=False)
    maps_api_key: Mapped[Optional[str]] = mapped_column(Text, nullable=True)     # encrypted
    gps_update_interval_seconds: Mapped[int] = mapped_column(Integer, default=10, nullable=False)

    # Payment
    payment_gateway: Mapped[str] = mapped_column(String(50), default="razorpay", nullable=False)
    payment_key_id: Mapped[Optional[str]] = mapped_column(Text, nullable=True)   # encrypted
    payment_key_secret: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # encrypted

    # Subscription rules
    weekly_deliveries: Mapped[int] = mapped_column(Integer, default=6, nullable=False)
    monthly_deliveries: Mapped[int] = mapped_column(Integer, default=26, nullable=False)
    max_pause_days_per_subscription: Mapped[int] = mapped_column(Integer, default=10, nullable=False)
    allow_carry_forward: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Tax & pricing
    tax_percentage: Mapped[float] = mapped_column(Numeric(5, 2), default=0.0, nullable=False)

    # Service availability
    service_available: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    maintenance_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    def __repr__(self) -> str:
        return f"<AdminSettings service_available={self.service_available}>"
