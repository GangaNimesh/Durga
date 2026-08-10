import re
import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.schemas.features import _ORMModel

PHONE_RE = r"^\+?[0-9\s\-()]{6,20}$"


# ── Requests ──


class RegisterRequest(BaseModel):
    email: EmailStr = Field(..., max_length=255, examples=["user@example.com"])
    password: str = Field(..., min_length=8, max_length=128)
    full_name: str = Field(..., max_length=255, examples=["Priya Sharma"])
    phone: str = Field(..., max_length=20, examples=["+919876543210"])

    @field_validator("email")
    @classmethod
    def _normalize_email(cls, value: str) -> str:
        # FIX: the unique index on User.email is case-sensitive on Postgres,
        # so "Alice@x.com" and "alice@x.com" would otherwise both register.
        return value.lower()

    @field_validator("password")
    @classmethod
    def _validate_password_strength(cls, value: str) -> str:
        if not re.search(r"[A-Za-z]", value) or not re.search(r"\d", value):
            raise ValueError("Password must contain at least one letter and one digit")
        return value

    @field_validator("phone")
    @classmethod
    def _validate_phone(cls, value: str) -> str:
        if not re.match(PHONE_RE, value):
            raise ValueError("Phone number is not a valid format")
        return value


class LoginRequest(BaseModel):
    email: EmailStr = Field(..., max_length=255)
    password: str = Field(..., min_length=8, max_length=128)

    @field_validator("email")
    @classmethod
    def _normalize_email(cls, value: str) -> str:
        return value.lower()


# ── Responses ──


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class UserResponse(_ORMModel):
    id: uuid.UUID
    email: str
    full_name: str
    phone: str
    is_active: bool
    created_at: datetime
