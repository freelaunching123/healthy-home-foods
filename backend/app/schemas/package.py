import uuid
from typing import Optional, List
from pydantic import BaseModel, Field

class PackageCartAddRequest(BaseModel):
    product_id: uuid.UUID
    quantity: int = Field(default=1, gt=0)

class PackageCartUpdateRequest(BaseModel):
    quantity: int = Field(gt=0)

class PackageCartItemResponse(BaseModel):
    id: uuid.UUID
    product_id: uuid.UUID
    product_name: str
    product_image_url: Optional[str] = None
    quantity: int
    unit_price: float
    subtotal: float

    model_config = {"from_attributes": True}

class PackageCartResponse(BaseModel):
    items: List[PackageCartItemResponse]
    total_amount: float
    item_count: int

    model_config = {"from_attributes": True}
