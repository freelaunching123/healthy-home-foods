import uuid
from typing import Optional
from pydantic import BaseModel


class ProductCategoryCreate(BaseModel):
    name: str
    slug: str
    description: Optional[str] = None
    image_url: Optional[str] = None
    parent_id: Optional[uuid.UUID] = None
    sort_order: int = 0


class ProductCategoryResponse(BaseModel):
    id: uuid.UUID
    name: str
    slug: str
    description: Optional[str]
    image_url: Optional[str]
    parent_id: Optional[uuid.UUID]
    sort_order: int
    is_active: bool

    model_config = {"from_attributes": True}


class ProductCreate(BaseModel):
    category_id: uuid.UUID
    name: str
    slug: str
    description: Optional[str] = None
    short_description: Optional[str] = None
    unit: str
    unit_size: Optional[float] = None
    price_per_unit: float
    mrp: Optional[float] = None
    sort_order: int = 0


class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    short_description: Optional[str] = None
    price_per_unit: Optional[float] = None
    mrp: Optional[float] = None
    is_available: Optional[bool] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None
    image_url: Optional[str] = None


class ProductResponse(BaseModel):
    id: uuid.UUID
    category_id: uuid.UUID
    name: str
    slug: str
    description: Optional[str]
    short_description: Optional[str]
    image_url: Optional[str]
    unit: str
    unit_size: Optional[float]
    price_per_unit: float
    mrp: Optional[float]
    is_available: bool
    is_active: bool
    sort_order: int

    model_config = {"from_attributes": True}


class ProductListResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[ProductResponse]
