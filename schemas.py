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
    username: str
    password: str

class LoginRequest(BaseModel):
    username: str
    password: str

class LoginResponse(BaseModel):
    token: str
    role: str
    id: str
    name: str
    is_priority: Optional[bool] = None

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

    class Config:
        from_attributes = True


class RouteInfo(BaseModel):
    path: Optional[list[str]] = None
    distance_m: Optional[float] = None
    eta_minutes: Optional[float] = None


class RideBookResponse(BaseModel):
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
    route: RouteInfo
    queue_position: Optional[int] = None
    total_active_rides: int
    group_id: Optional[int] = None
    group_size: Optional[int] = None  # total passengers currently in this ride's carpool group

    class Config:
        from_attributes = True

class GucianAdminView(BaseModel):
    id: str
    firstname: str
    lastname: str
    email: str
    faculty: Optional[str] = None
    username: str
    createdat: datetime

    class Config:
        from_attributes = True

class MedicalRequestResponse(BaseModel):
    id: int
    gucian_id: str
    request_type: str
    document_path: str
    status: str
    priority_days: Optional[int] = None
    priority_until: Optional[datetime] = None
    reviewed_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True

class MedicalRequestAdminView(BaseModel):
    id: int
    gucian_id: str
    gucian_name: str
    request_type: str
    document_path: str
    status: str
    priority_days: Optional[int] = None
    priority_until: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True

class MedicalRequestReview(BaseModel):
    status: str  # "approved" or "rejected"
    priority_days: Optional[int] = None  # required if approving an injury request

    @field_validator("status")
    @classmethod
    def validate_status(cls, v):
        if v not in ("approved", "rejected"):
            raise ValueError("status must be 'approved' or 'rejected'")
        return v

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class VerifyResetCodeRequest(BaseModel):
    email: EmailStr
    code: str

class ResetPasswordRequest(BaseModel):
    reset_token: str
    new_password: str

class SendItemCreate(BaseModel):
    pickup_location_id: int
    dropoff_location_id: int
    item_description: str
    recipient_id: Optional[str] = None

class SendItemResponse(BaseModel):
    id: int
    sender_id: str
    recipient_id: Optional[str] = None
    pickup_location_id: int
    dropoff_location_id: int
    item_description: str
    status: str
    created_at: datetime
    delivered_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class RideCancelResponse(BaseModel):
    ride_id: int
    status: str
    message: str

class RatingCreate(BaseModel):
    stars: int
    smoothness: Optional[int] = None
    punctuality: Optional[int] = None
    cleanliness: Optional[int] = None
    comment: Optional[str] = None

    @field_validator("stars", "smoothness", "punctuality", "cleanliness")
    @classmethod
    def validate_range(cls, v):
        if v is not None and (v < 1 or v > 5):
            raise ValueError("Rating values must be between 1 and 5")
        return v

class RatingResponse(BaseModel):
    id: int
    ride_id: int
    gucian_id: str
    stars: int
    smoothness: Optional[int] = None
    punctuality: Optional[int] = None
    cleanliness: Optional[int] = None
    comment: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

class RatingAdminView(BaseModel):
    id: int
    ride_id: int
    gucian_name: str
    stars: int
    smoothness: Optional[int] = None
    punctuality: Optional[int] = None
    cleanliness: Optional[int] = None
    comment: Optional[str] = None
    created_at: datetime

class RideHistoryItem(BaseModel):
    ride_id: int
    status: str
    pickup_name: str
    destination_name: str
    created_at: datetime
    completed_at: Optional[datetime] = None
    rating: Optional[RatingResponse] = None
 
    class Config:
        from_attributes = True   