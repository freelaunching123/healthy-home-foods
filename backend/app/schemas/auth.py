from typing import Optional
from pydantic import BaseModel, field_validator
import re


class SendOtpRequest(BaseModel):
    phone: str
    purpose: str = "login"


class RegisterRequest(BaseModel):
    full_name: str
    mobile_number: str
    password: Optional[str] = None

    @field_validator("mobile_number")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        v = v.strip().lstrip("+")
        if v.startswith("91") and len(v) == 12:
            v = v[2:]
        if not re.fullmatch(r"[6-9]\d{9}", v):
            raise ValueError("Invalid Indian phone number")
        return v


class VerifyOtpRequest(BaseModel):
    phone: str
    otp: str
    purpose: str = "login"

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        v = v.strip().lstrip("+")
        if v.startswith("91") and len(v) == 12:
            v = v[2:]
        if not re.fullmatch(r"[6-9]\d{9}", v):
            raise ValueError("Invalid Indian phone number")
        return v

    @field_validator("otp")
    @classmethod
    def validate_otp(cls, v: str) -> str:
        if not re.fullmatch(r"\d{4,8}", v):
            raise ValueError("OTP must be 4-8 digits")
        return v


class AdminLoginRequest(BaseModel):
    email: Optional[str] = None
    mobile_number: Optional[str] = None
    password: str
    role: Optional[str] = None


class LoginPasswordRequest(BaseModel):
    """Phone + password login (for admin / seeded users)."""
    phone: str
    password: str
    role: Optional[str] = None


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str
    role: str
    full_name: str


class RegisterResponse(BaseModel):
    message: str
    user_id: str
    success: bool = True


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class ForgotPasswordRequest(BaseModel):
    mobile_number: str
    new_password: str

    @field_validator("mobile_number")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        import re
        v = v.strip().lstrip("+")
        if v.startswith("91") and len(v) == 12:
            v = v[2:]
        if not re.fullmatch(r"[6-9]\d{9}", v):
            raise ValueError("Invalid Indian phone number")
        return v

