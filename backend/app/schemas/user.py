import uuid
from datetime import datetime, date
from typing import Optional
from pydantic import BaseModel, EmailStr, field_validator
import re


class UserBase(BaseModel):
    full_name: str
    email: Optional[EmailStr] = None
    phone: str

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        v = v.strip().lstrip("+")
        if v.startswith("91") and len(v) == 12:
            v = v[2:]
        if not re.fullmatch(r"[6-9]\d{9}", v):
            raise ValueError("Invalid Indian phone number")
        return v


class UserCreate(UserBase):
    password: Optional[str] = None
    role: str = "customer"


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    profile_photo_url: Optional[str] = None
    fcm_token: Optional[str] = None
    device_type: Optional[str] = None
    notification_enabled: Optional[bool] = None
    gender: Optional[str] = None
    dob: Optional[date] = None
    delivery_notifications_enabled: Optional[bool] = None
    payment_notifications_enabled: Optional[bool] = None
    promotional_notifications_enabled: Optional[bool] = None
    photo_base64: Optional[str] = None


class UserResponse(BaseModel):
    id: uuid.UUID
    phone: str
    email: Optional[str]
    full_name: str
    status: str
    is_verified: bool
    profile_photo_url: Optional[str]
    created_at: datetime
    gender: Optional[str] = None
    dob: Optional[date] = None
    delivery_notifications_enabled: bool = True
    payment_notifications_enabled: bool = True
    promotional_notifications_enabled: bool = True
    fcm_token: Optional[str] = None
    device_type: Optional[str] = None
    notification_enabled: bool = True
    last_token_update: Optional[datetime] = None

    model_config = {"from_attributes": True}


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str


class UserListResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[UserResponse]
