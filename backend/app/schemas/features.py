import re
import uuid
from datetime import datetime, timezone
from typing import Optional, List
from pydantic import BaseModel, Field, field_serializer, field_validator

PHONE_RE = r"^\+?[0-9\s\-()]{6,20}$"


class _ORMModel(BaseModel):
    """Shared base for response schemas backed by ORM objects.

    FIX: naive datetimes coming out of the DB (no tzinfo) were serialized
    without a UTC offset. Dart's DateTime.parse() treats offset-less strings
    as local time, so every timestamp was wrong by the device's UTC offset.
    """

    model_config = {"from_attributes": True}

    @field_serializer("created_at", "updated_at", check_fields=False, when_used="json")
    def _serialize_utc(self, value: Optional[datetime]) -> Optional[str]:
        if value is None:
            return None
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.isoformat()


# Contact Schemas
class ContactBase(BaseModel):
    name: str = Field(..., max_length=255)
    phone: str = Field(..., max_length=20)
    relation: Optional[str] = Field(None, max_length=100)

    @field_validator("phone")
    @classmethod
    def _validate_phone(cls, value: str) -> str:
        if not re.match(PHONE_RE, value):
            raise ValueError("Phone number is not a valid format")
        return value

class ContactCreate(ContactBase):
    pass

# FIX: ContactUpdate inherited ContactBase's required fields, so
# exclude_unset=True in the handler was dead code - any partial update
# (e.g. {"name": "Mummy"}) 422'd on the missing required fields.
class ContactUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=255)
    phone: Optional[str] = Field(None, max_length=20)
    relation: Optional[str] = Field(None, max_length=100)

    @field_validator("phone")
    @classmethod
    def _validate_phone(cls, value: Optional[str]) -> Optional[str]:
        if value is not None and not re.match(PHONE_RE, value):
            raise ValueError("Phone number is not a valid format")
        return value

class ContactResponse(ContactBase, _ORMModel):
    id: uuid.UUID
    user_id: uuid.UUID
    created_at: datetime
    updated_at: datetime

# SOSAlert Schemas
class SOSAlertBase(BaseModel):
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)

class SOSAlertCreate(SOSAlertBase):
    pass

class SOSAlertResponse(SOSAlertBase, _ORMModel):
    id: uuid.UUID
    user_id: uuid.UUID
    is_active: bool
    created_at: datetime
    updated_at: datetime

# Journey Schemas
class JourneyBase(BaseModel):
    start_latitude: Optional[float] = Field(None, ge=-90, le=90)
    start_longitude: Optional[float] = Field(None, ge=-180, le=180)
    dest_latitude: Optional[float] = Field(None, ge=-90, le=90)
    dest_longitude: Optional[float] = Field(None, ge=-180, le=180)

class JourneyCreate(JourneyBase):
    pass

class JourneyUpdate(BaseModel):
    dest_latitude: Optional[float] = Field(None, ge=-90, le=90)
    dest_longitude: Optional[float] = Field(None, ge=-180, le=180)
    is_active: Optional[bool] = None

class JourneyResponse(JourneyBase, _ORMModel):
    id: uuid.UUID
    user_id: uuid.UUID
    is_active: bool
    created_at: datetime
    updated_at: datetime

# Evidence Schemas
class EvidenceBase(BaseModel):
    file_path: str = Field(..., max_length=500)
    file_type: str = Field(..., max_length=50)

class EvidenceCreate(EvidenceBase):
    pass

class EvidenceResponse(EvidenceBase, _ORMModel):
    id: uuid.UUID
    user_id: uuid.UUID
    created_at: datetime

# Helpline Schemas
class HelplineBase(BaseModel):
    name: str = Field(..., max_length=255)
    phone: str = Field(..., max_length=20)
    category: Optional[str] = Field(None, max_length=100)

class HelplineResponse(HelplineBase, _ORMModel):
    id: uuid.UUID

# Threat Schemas
class ThreatRequest(BaseModel):
    text: str

class ThreatResponse(BaseModel):
    risk_level: str
    color: str
    score: int
    matched_keywords: List[str]
