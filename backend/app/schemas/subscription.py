import uuid
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel


class SubscriptionItemCreate(BaseModel):
    product_id: uuid.UUID
    quantity: int = 1


class SubscriptionItemResponse(BaseModel):
    id: uuid.UUID
    product_id: uuid.UUID
    product_name: Optional[str] = None
    quantity: int
    price_per_delivery: Optional[float] = None
    package_price: Optional[float] = None

    model_config = {"from_attributes": True}


class SubscriptionCreate(BaseModel):
    plan_id: Optional[uuid.UUID] = None
    items: list[SubscriptionItemCreate]
    address_id: uuid.UUID
    preferred_delivery_time: Optional[str] = None
    auto_renew: bool = False
    notes: Optional[str] = None


class SubscriptionUpdate(BaseModel):
    address_id: Optional[uuid.UUID] = None
    preferred_delivery_time: Optional[str] = None
    auto_renew: Optional[bool] = None
    notes: Optional[str] = None
    items: Optional[list[SubscriptionItemCreate]] = None


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


class SubscriptionStatusHistoryResponse(BaseModel):
    id: uuid.UUID
    old_status: str
    new_status: str
    changed_at: datetime
    reason: Optional[str] = None

    model_config = {"from_attributes": True}


class SubscriptionPauseHistoryResponse(BaseModel):
    id: uuid.UUID
    paused_at: datetime
    resumed_at: Optional[datetime] = None
    pause_reason: Optional[str] = None
    paused_days: int

    model_config = {"from_attributes": True}


class SubscriptionPaymentHistoryResponse(BaseModel):
    id: uuid.UUID
    payment_id: Optional[uuid.UUID] = None
    amount: float
    status: str
    transaction_id: Optional[str] = None
    changed_at: datetime

    model_config = {"from_attributes": True}


class SubscriptionResponse(BaseModel):
    id: uuid.UUID
    plan_id: Optional[uuid.UUID] = None
    product_id: Optional[uuid.UUID] = None
    address_id: uuid.UUID
    status: str
    total_deliveries: int
    completed_deliveries: int
    missed_deliveries: int
    start_date: Optional[date] = None
    expected_end_date: Optional[date] = None
    package_price: Optional[float] = None
    price_per_delivery: Optional[float] = None
    total_amount: float
    delivery_charge: float
    tax_amount: float
    auto_renew: bool
    preferred_delivery_time: Optional[str] = None
    created_at: datetime
    items: list[SubscriptionItemResponse] = []
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    plan_name: Optional[str] = None
    plan_type: Optional[str] = None
    product_name: Optional[str] = None
    display_order_id: Optional[str] = None

    model_config = {"from_attributes": True}


class SubscriptionDetailResponse(SubscriptionResponse):
    status_history: list[SubscriptionStatusHistoryResponse] = []
    pause_history: list[SubscriptionPauseHistoryResponse] = []
    payment_history: list[SubscriptionPaymentHistoryResponse] = []


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


class TodayDeliveryInfo(BaseModel):
    delivery_id: Optional[str] = None
    order_id: Optional[str] = None
    status: Optional[str] = None
    partner_name: Optional[str] = None
    partner_phone: Optional[str] = None
    estimated_minutes: Optional[int] = None


class CurrentSubscriptionResponse(BaseModel):
    id: uuid.UUID
    plan_name: str
    plan_type: str
    start_date: Optional[date] = None
    expected_end_date: Optional[date] = None
    status: str
    total_deliveries: int
    completed_deliveries: int
    remaining_deliveries: int
    paused_days: int
    missed_deliveries: int
    carry_forward_deliveries: int
    product_name: str
    package_price: Optional[float] = None
    price_per_delivery: Optional[float] = None
    total_amount: float
    next_delivery_date: Optional[date] = None
    today_delivery: Optional[TodayDeliveryInfo] = None
    display_order_id: Optional[str] = None

    model_config = {"from_attributes": True}

