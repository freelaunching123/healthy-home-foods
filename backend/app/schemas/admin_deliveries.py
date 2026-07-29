import uuid
from datetime import datetime, date
from typing import Optional, List
from pydantic import BaseModel


class AdminDeliveryListItem(BaseModel):
    id: uuid.UUID
    subscription_id: Optional[uuid.UUID] = None
    customer_name: str
    phone: str
    delivery_partner_id: Optional[uuid.UUID] = None
    delivery_partner_name: Optional[str] = None
    delivery_partner_phone: Optional[str] = None
    delivery_address: str
    scheduled_date: date
    delivery_time: Optional[str] = None
    amount: float
    payment_status: str
    status: str

    class Config:
        from_attributes = True


class AdminDeliveryProduct(BaseModel):
    product_name: str
    quantity: int
    price_per_delivery: float


class AdminDeliveryCustomer(BaseModel):
    id: uuid.UUID
    full_name: str
    phone: str
    email: Optional[str] = None
    customer_code: str


class AdminDeliveryPartner(BaseModel):
    id: uuid.UUID
    full_name: str
    phone: str
    employee_code: str
    vehicle_type: Optional[str] = None
    vehicle_number: Optional[str] = None


class AdminDeliveryAddress(BaseModel):
    id: uuid.UUID
    address_line1: str
    address_line2: Optional[str] = None
    city: str
    state: str
    pincode: str
    landmark: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class AdminDeliveryTimelineStep(BaseModel):
    stage: str
    completed: bool
    timestamp: Optional[datetime] = None


class AdminDeliveryAssignmentLog(BaseModel):
    previous_partner_name: Optional[str] = None
    new_partner_name: Optional[str] = None
    changed_by_name: Optional[str] = None
    changed_at: datetime


class AdminDeliveryDetail(BaseModel):
    id: uuid.UUID
    subscription_id: uuid.UUID
    scheduled_date: date
    status: str
    delivered_at: Optional[datetime] = None
    delivery_proof_url: Optional[str] = None
    customer_rating: Optional[int] = None
    customer_feedback: Optional[str] = None
    notes: Optional[str] = None
    amount: float
    payment_method: Optional[str] = None
    payment_status: str
    preferred_delivery_time: Optional[str] = None
    customer: AdminDeliveryCustomer
    delivery_partner: Optional[AdminDeliveryPartner] = None
    address: AdminDeliveryAddress
    products: List[AdminDeliveryProduct]
    timeline: List[AdminDeliveryTimelineStep]
    assignment_history: List[AdminDeliveryAssignmentLog]

    class Config:
        from_attributes = True


class AdminDeliveryStatusUpdate(BaseModel):
    status: str
    failure_reason: Optional[str] = None


class AdminDeliveryAssignRequest(BaseModel):
    delivery_partner_id: uuid.UUID


class AdminDeliveryAnalytics(BaseModel):
    total_deliveries: int
    delivered: int
    pending: int
    assigned: int
    out_for_delivery: int
    failed: int
    cancelled: int
    success_rate: float
    average_delivery_time: float  # in minutes
    top_partner_name: Optional[str] = None
