import uuid
from datetime import datetime
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


class UserResponse(BaseModel):
    id: uuid.UUID
    phone: str
    email: Optional[str]
    full_name: str
    status: str
    is_verified: bool
    profile_photo_url: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class UserListResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[UserResponse]
