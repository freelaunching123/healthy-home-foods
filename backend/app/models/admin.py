import uuid
from typing import Optional
from sqlalchemy import String, Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import mapped_column, Mapped, relationship
from app.db.base import Base
from app.db.mixins import UUIDPrimaryKeyMixin, TimestampMixin


class Admin(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Admin profile — one-to-one with User."""

    __tablename__ = "admins"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
        unique=True, nullable=False, index=True
    )
    is_super_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    department: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="admin")

    def __repr__(self) -> str:
        return f"<Admin user_id={self.user_id} super={self.is_super_admin}>"
