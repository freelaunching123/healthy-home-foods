import uuid
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel


class SubscriptionCreate(BaseModel):
    plan_id: uuid.UUID
    product_id: uuid.UUID
    address_id: uuid.UUID
    preferred_delivery_time: Optional[str] = None
    auto_renew: bool = False
    notes: Optional[str] = None


class SubscriptionPauseRequest(BaseModel):
    reason: Optional[str] = None


class SubscriptionResumeRequest(BaseModel):
    pass


class SubscriptionCancelRequest(BaseModel):
    reason: str


class SubscriptionPlanResponse(BaseModel):
    id: uuid.UUID
    name: str
    plan_type: str
    total_deliveries: int
    description: Optional[str]
    is_active: bool

    model_config = {"from_attributes": True}


class SubscriptionResponse(BaseModel):
    id: uuid.UUID
    plan_id: uuid.UUID
    product_id: uuid.UUID
    address_id: uuid.UUID
    status: str
    total_deliveries: int
    completed_deliveries: int
    missed_deliveries: int
    start_date: Optional[date]
    expected_end_date: Optional[date]
    price_per_delivery: float
    total_amount: float
    delivery_charge: float
    tax_amount: float
    auto_renew: bool
    preferred_delivery_time: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class DeliveryResponse(BaseModel):
    id: uuid.UUID
    subscription_id: uuid.UUID
    scheduled_date: date
    status: str
    delivered_at: Optional[datetime]
    delivery_proof_url: Optional[str]
    customer_rating: Optional[int]
    customer_feedback: Optional[str]
    is_carry_forward: bool

    model_config = {"from_attributes": True}


class DeliveryListResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[DeliveryResponse]
