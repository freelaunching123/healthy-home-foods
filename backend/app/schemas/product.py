import uuid
from typing import Optional
from pydantic import BaseModel
from app.models.product import ProductStatus, ProductAvailability


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
    price: float
    discount_price: Optional[float] = None
    status: ProductStatus = ProductStatus.DRAFT
    availability: ProductAvailability = ProductAvailability.AVAILABLE
    display_order: int = 0
    is_featured: bool = False
    is_popular: bool = False
    is_today_special: bool = False


class ProductUpdate(BaseModel):
    category_id: Optional[uuid.UUID] = None
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    discount_price: Optional[float] = None
    status: Optional[ProductStatus] = None
    availability: Optional[ProductAvailability] = None
    display_order: Optional[int] = None
    is_featured: Optional[bool] = None
    is_popular: Optional[bool] = None
    is_today_special: Optional[bool] = None
    is_active: Optional[bool] = None
    image_url: Optional[str] = None


class ProductResponse(BaseModel):
    id: uuid.UUID
    category_id: uuid.UUID
    name: str
    slug: str
    description: Optional[str]
    image_url: Optional[str]
    price: float
    discount_price: Optional[float]
    status: ProductStatus
    availability: ProductAvailability
    display_order: int
    is_featured: bool
    is_popular: bool
    is_today_special: bool
    is_active: bool

    model_config = {"from_attributes": True}


class ProductListResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[ProductResponse]
