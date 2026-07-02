from uuid import UUID
from typing import Optional
from datetime import datetime
from pydantic import BaseModel, Field

from app.models.review import ReviewItemType


class ReviewCreate(BaseModel):
    rating: int = Field(..., ge=1, le=5, description="Rating from 1 to 5")
    review_text: Optional[str] = Field(None, description="Optional text review")


class ReviewResponse(BaseModel):
    id: UUID
    customer_id: UUID
    customer_name: str
    item_type: ReviewItemType
    item_id: UUID
    rating: int
    review_text: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


class ReviewListResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[ReviewResponse]
    average_rating: float
