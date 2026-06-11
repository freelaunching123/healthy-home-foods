import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class AddressCreate(BaseModel):
    label: Optional[str] = None
    address_type: str = "home"
    address_line1: str
    address_line2: Optional[str] = None
    city: str
    state: str
    pincode: str
    landmark: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    is_default: bool = False


class AddressUpdate(BaseModel):
    label: Optional[str] = None
    address_line1: Optional[str] = None
    address_line2: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    landmark: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    is_default: Optional[bool] = None


class AddressResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    label: Optional[str]
    address_type: str
    address_line1: str
    address_line2: Optional[str]
    city: str
    state: str
    pincode: str
    landmark: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    is_default: bool
    is_active: bool

    model_config = {"from_attributes": True}


# ── Payment schemas ────────────────────────────────────────────────────────────

class PaymentInitiateRequest(BaseModel):
    subscription_id: uuid.UUID


class PaymentVerifyRequest(BaseModel):
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str


class PaymentResponse(BaseModel):
    id: uuid.UUID
    subscription_id: uuid.UUID
    gateway_order_id: Optional[str]
    gateway_payment_id: Optional[str]
    amount: float
    currency: str
    status: str
    payment_method: Optional[str]
    paid_at: Optional[datetime]

    model_config = {"from_attributes": True}


# ── GPS schemas ────────────────────────────────────────────────────────────────

class GpsUpdateRequest(BaseModel):
    assignment_id: uuid.UUID
    latitude: float
    longitude: float
    accuracy_meters: Optional[float] = None
    speed_kmph: Optional[float] = None
    heading: Optional[float] = None


class GpsLocationResponse(BaseModel):
    latitude: float
    longitude: float
    accuracy_meters: Optional[float]
    speed_kmph: Optional[float]
    recorded_at: datetime
    delivery_boy_name: Optional[str] = None
    estimated_minutes: Optional[int] = None


# ── Delivery assignment schemas ────────────────────────────────────────────────

class AssignDeliveryRequest(BaseModel):
    delivery_id: uuid.UUID
    delivery_boy_id: uuid.UUID


class UpdateDeliveryStatusRequest(BaseModel):
    status: str  # accepted | out_for_delivery | delivered | failed
    failure_reason: Optional[str] = None


class AssignmentResponse(BaseModel):
    id: uuid.UUID
    delivery_id: uuid.UUID
    delivery_boy_id: uuid.UUID
    status: str
    assigned_at: datetime
    distance_km: Optional[float]
    estimated_minutes: Optional[int]

    model_config = {"from_attributes": True}


# ── Admin settings schemas ─────────────────────────────────────────────────────

class AdminSettingsUpdate(BaseModel):
    free_delivery_radius_km: Optional[float] = None
    delivery_charge_per_km: Optional[float] = None
    business_name: Optional[str] = None
    business_address: Optional[str] = None
    business_lat: Optional[float] = None
    business_lng: Optional[float] = None
    business_phone: Optional[str] = None
    business_email: Optional[str] = None
    working_hours_start: Optional[str] = None
    working_hours_end: Optional[str] = None
    sms_notifications_enabled: Optional[bool] = None
    email_notifications_enabled: Optional[bool] = None
    push_notifications_enabled: Optional[bool] = None
    maps_provider: Optional[str] = None
    gps_update_interval_seconds: Optional[int] = None
    payment_gateway: Optional[str] = None
    weekly_deliveries: Optional[int] = None
    monthly_deliveries: Optional[int] = None
    max_pause_days_per_subscription: Optional[int] = None
    allow_carry_forward: Optional[bool] = None
    tax_percentage: Optional[float] = None
    service_available: Optional[bool] = None
    maintenance_message: Optional[str] = None


class AdminSettingsResponse(BaseModel):
    id: int
    free_delivery_radius_km: float
    delivery_charge_per_km: float
    business_name: str
    business_address: Optional[str]
    business_phone: Optional[str]
    business_email: Optional[str]
    working_hours_start: Optional[str]
    working_hours_end: Optional[str]
    sms_notifications_enabled: bool
    email_notifications_enabled: bool
    push_notifications_enabled: bool
    maps_provider: str
    gps_update_interval_seconds: int
    payment_gateway: str
    weekly_deliveries: int
    monthly_deliveries: int
    max_pause_days_per_subscription: int
    allow_carry_forward: bool
    tax_percentage: float
    service_available: bool
    maintenance_message: Optional[str]

    model_config = {"from_attributes": True}


# ── Report schemas ─────────────────────────────────────────────────────────────

class DashboardStats(BaseModel):
    daily_revenue: float
    weekly_revenue: float
    monthly_revenue: float
    active_subscriptions: int
    expired_subscriptions: int
    total_customers: int
    new_customers_this_month: int
    delivery_success_rate: float
    pending_deliveries: int
    missed_deliveries_today: int


class DeliveryBoyPerformance(BaseModel):
    delivery_boy_id: uuid.UUID
    name: str
    total_assigned: int
    total_delivered: int
    success_rate: float
    avg_rating: Optional[float]


# ── Common response ────────────────────────────────────────────────────────────

class MessageResponse(BaseModel):
    message: str
    success: bool = True
