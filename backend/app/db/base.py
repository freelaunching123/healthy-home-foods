import uuid
from datetime import datetime
from sqlalchemy.orm import DeclarativeBase, declared_attr
from sqlalchemy import DateTime, func
from sqlalchemy.dialects.postgresql import UUID


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy models."""

    @declared_attr.directive
    def __tablename__(cls) -> str:  # noqa: N805
        # Auto-generate table name from class name (snake_case)
        import re
        name = re.sub(r"(?<!^)(?=[A-Z])", "_", cls.__name__).lower()
        return name

    # Every table gets these audit columns automatically
    created_at: datetime = None  # overridden per model or via mixin
    updated_at: datetime = None
