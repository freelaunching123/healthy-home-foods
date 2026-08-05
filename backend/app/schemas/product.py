import uuid
from typing import Optional, Literal
from pydantic import BaseModel, root_validator, model_validator
from app.models.product import ProductStatus, ProductAvailability


class ProductCategoryCreate(BaseModel):
    name: str
    slug: str
    description: Optional[str] = None
    image_url: Optional[str] = None
    parent_id: Optional[uuid.UUID] = None
    sort_order: int = 0
    category_type: Optional[str] = "package"


class ProductCategoryResponse(BaseModel):
    id: uuid.UUID
    name: str
    slug: str
    description: Optional[str]
    image_url: Optional[str]
    parent_id: Optional[uuid.UUID]
    sort_order: int
    category_type: str = "package"
    is_active: bool

    model_config = {"from_attributes": True}


class ProductCreate(BaseModel):
    category_id: uuid.UUID
    name: str
    slug: str
    description: Optional[str] = None
    plan_type: Literal['weekly', 'monthly']
    package_days: int
    package_price: float
    discount_price: Optional[float] = None
    
    @model_validator(mode='after')
    def validate_plan(self) -> 'ProductCreate':
        if self.plan_type == 'weekly' and self.package_days != 6:
            raise ValueError("Weekly plan must have 6 package days")
        if self.plan_type == 'monthly' and self.package_days != 26:
            raise ValueError("Monthly plan must have 26 package days")
        return self
    status: ProductStatus = ProductStatus.PUBLISHED
    availability: ProductAvailability = ProductAvailability.AVAILABLE
    display_order: int = 0
    is_featured: bool = False
    is_popular: bool = False
    is_today_special: bool = False


class ProductUpdate(BaseModel):
    category_id: Optional[uuid.UUID] = None
    name: Optional[str] = None
    description: Optional[str] = None
    plan_type: Optional[Literal['weekly', 'monthly']] = None
    package_days: Optional[int] = None
    package_price: Optional[float] = None
    discount_price: Optional[float] = None
    status: Optional[ProductStatus] = None
    availability: Optional[ProductAvailability] = None
    display_order: Optional[int] = None
    is_featured: Optional[bool] = None
    is_popular: Optional[bool] = None
    is_today_special: Optional[bool] = None
    is_active: Optional[bool] = None
    image_url: Optional[str] = None
    
    @model_validator(mode='after')
    def validate_plan(self) -> 'ProductUpdate':
        if self.plan_type == 'weekly' and self.package_days is not None and self.package_days != 6:
            raise ValueError("Weekly plan must have 6 package days")
        if self.plan_type == 'monthly' and self.package_days is not None and self.package_days != 26:
            raise ValueError("Monthly plan must have 26 package days")
        return self


class ProductResponse(BaseModel):
    id: uuid.UUID
    category_id: uuid.UUID
    category_name: Optional[str]
    category: Optional[ProductCategoryResponse]
    name: str
    slug: str
    description: Optional[str]
    image_url: Optional[str]
    plan_type: str
    package_days: int
    package_price: float
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
