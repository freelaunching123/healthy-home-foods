import uuid
from typing import Optional
from datetime import datetime
from sqlalchemy import String, ForeignKey, Text, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin


class AuditLog(UUIDPrimaryKeyMixin, Base):
    """Immutable audit trail — who changed what and when."""

    __tablename__ = "audit_logs"

    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True, index=True
    )
    action: Mapped[str] = mapped_column(String(100), nullable=False, index=True)  # e.g. "subscription.paused"
    entity_type: Mapped[str] = mapped_column(String(100), nullable=False, index=True)  # e.g. "Subscription"
    entity_id: Mapped[Optional[str]] = mapped_column(String(50), nullable=True, index=True)
    old_value: Mapped[Optional[str]] = mapped_column(Text, nullable=True)   # JSON string
    new_value: Mapped[Optional[str]] = mapped_column(Text, nullable=True)   # JSON string
    ip_address: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)

    user: Mapped[Optional["User"]] = relationship("User", back_populates="audit_logs")
