import uuid
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, field_validator


# ── Fruit Schemas ──────────────────────────────────────────────────────────────

class FruitCreate(BaseModel):
    name: str
    description: Optional[str] = None
    price_per_kg: float
    availability_status: str = "in_stock"
    is_active: bool = True

    @field_validator("price_per_kg")
    @classmethod
    def validate_price(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("price_per_kg must be greater than 0")
        return round(v, 2)

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Fruit name cannot be empty")
        return v


class FruitUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price_per_kg: Optional[float] = None
    availability_status: Optional[str] = None
    is_active: Optional[bool] = None

    @field_validator("price_per_kg")
    @classmethod
    def validate_price(cls, v: Optional[float]) -> Optional[float]:
        if v is not None and v <= 0:
            raise ValueError("price_per_kg must be greater than 0")
        return v


class FruitResponse(BaseModel):
    id: uuid.UUID
    name: str
    description: Optional[str]
    price_per_kg: float
    image_url: Optional[str]
    availability_status: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class FruitAvailabilityUpdate(BaseModel):
    availability_status: str  # in_stock | out_of_stock | temporarily_unavailable


# ── Cart Schemas ───────────────────────────────────────────────────────────────

class FruitCartAddRequest(BaseModel):
    fruit_id: uuid.UUID
    quantity_kg: float

    @field_validator("quantity_kg")
    @classmethod
    def validate_qty(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("quantity_kg must be greater than 0")
        return round(v, 3)


class FruitCartUpdateRequest(BaseModel):
    quantity_kg: float

    @field_validator("quantity_kg")
    @classmethod
    def validate_qty(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("quantity_kg must be greater than 0")
        return round(v, 3)


class FruitCartItemResponse(BaseModel):
    id: uuid.UUID
    fruit_id: uuid.UUID
    fruit_name: str
    fruit_image_url: Optional[str]
    fruit_availability_status: str
    quantity_kg: float
    unit_price: float
    subtotal: float

    model_config = {"from_attributes": True}


class FruitCartResponse(BaseModel):
    items: List[FruitCartItemResponse]
    total_amount: float
    item_count: int


# ── Order Schemas ──────────────────────────────────────────────────────────────

class FruitCheckoutRequest(BaseModel):
    address_id: uuid.UUID
    notes: Optional[str] = None


class FruitOrderItemResponse(BaseModel):
    id: uuid.UUID
    fruit_id: uuid.UUID
    fruit_name: str
    fruit_image_url: Optional[str]
    quantity_kg: float
    price_per_kg: float
    subtotal: float

    model_config = {"from_attributes": True}


class FruitOrderResponse(BaseModel):
    id: uuid.UUID
    order_number: str
    total_amount: float
    payment_status: str
    order_status: str
    gateway_order_id: Optional[str]
    gateway_payment_id: Optional[str]
    paid_at: Optional[datetime]
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime
    items: List[FruitOrderItemResponse] = []
    # Address snapshot
    address_line1: Optional[str] = None
    address_city: Optional[str] = None
    # Customer info (admin view)
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    # Assigned partner (admin view)
    assigned_partner_id: Optional[uuid.UUID] = None
    assigned_partner_name: Optional[str] = None

    model_config = {"from_attributes": True}


class AdminFruitOrderAssignRequest(BaseModel):
    delivery_partner_id: Optional[uuid.UUID] = None


class FruitOrderStatusUpdate(BaseModel):
    order_status: str  # pending | preparing | ready | out_for_delivery | delivered | cancelled


class FruitPaymentVerifyRequest(BaseModel):
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str
