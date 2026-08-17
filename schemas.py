from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

EGYPT_TZ = ZoneInfo("Africa/Cairo")



class GucianSignup(BaseModel):
    id: str
    firstname: str
    lastname: str
    email: EmailStr
    faculty: Optional[str] = None
    isinjured: bool = False
    username: str
    password: str

class LoginRequest(BaseModel):
    username: str
    password: str

class LoginResponse(BaseModel):
    token: str
    role: str          # "admin" or "student"
    id: str
    name: str
    isinjured: Optional[bool] = None

class RideCreate(BaseModel):
    pickup_location_id: int
    destination_location_id: int
    passenger_count: int = 1
    is_prebooked: bool = False
    scheduled_time: Optional[datetime] = None

    @field_validator("passenger_count")
    @classmethod
    def validate_passenger_count(cls, v):
        if v < 1 or v >= 5:
            raise ValueError("passenger_count must be between 1 and 4")
        return v


class RideScheduleCreate(BaseModel):
    pickup_location_id: int
    destination_location_id: int
    passenger_count: int = 1
    scheduled_time: datetime

    @field_validator("passenger_count")
    @classmethod
    def validate_passenger_count(cls, v):
        if v < 1 or v >= 5:
            raise ValueError("passenger_count must be between 1 and 4")
        return v

    @field_validator("scheduled_time")
    @classmethod
    def validate_scheduled_time(cls, v):
        if v.tzinfo is None:
            v = v.replace(tzinfo=EGYPT_TZ)

        now = datetime.now(EGYPT_TZ)
        max_advance = now + timedelta(hours=24)

        if v <= now:
            raise ValueError("scheduled_time must be in the future")
        if v > max_advance:
            raise ValueError("scheduled_time cannot be more than 24 hours in advance")
        return v

class RideResponse(BaseModel):
    id: int
    user_id: str
    pickup_location_id: int
    destination_location_id: int
    status: str
    is_priority: bool
    is_prebooked: bool
    scheduled_time: Optional[datetime] = None
    passenger_count: int
    verification_code: Optional[str] = None
    created_at: datetime
    class Config:
        from_attributes = True

class LocationResponse(BaseModel):
    id: int
    name: str
    latitude: float
    longitude: float

    class Config:
        from_attributes = True