from sqlalchemy import (
    Column, Integer, String, Float, Boolean,
    ForeignKey, DateTime, CheckConstraint
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base


class Admin(Base):
    __tablename__ = "admin"

    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    username = Column(String(100), nullable=False)
    password = Column(String(100), nullable=False)


class Gucian(Base):
    __tablename__ = "gucians"

    id = Column(String(50), primary_key=True)
    firstname = Column(String(100), nullable=False)
    lastname = Column(String(100), nullable=False)
    email = Column(String(150), unique=True, nullable=False)
    faculty = Column(String(50))
    is_priority = Column(Boolean, default=False)
    priority_until = Column(DateTime(timezone=True), nullable=True)
    username = Column(String(100), nullable=False)
    password = Column(String(100), nullable=False)
    createdat = Column(DateTime(timezone=True), server_default=func.now())


class Location(Base):
    __tablename__ = "locations"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)


class RideGroup(Base):
    __tablename__ = "ride_groups"

    id = Column(Integer, primary_key=True, index=True)
    pickup_location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)
    destination_location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)
    passenger_total = Column(Integer, nullable=False, default=0)
    locked = Column(Boolean, nullable=False, default=False)
    assigned_car_id = Column(Integer, ForeignKey("cars.id"), nullable=True)  # ADD THIS LINE
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    pickup_location = relationship("Location", foreign_keys=[pickup_location_id])
    destination_location = relationship("Location", foreign_keys=[destination_location_id])
    rides = relationship("Ride", back_populates="group")


class Ride(Base):
    __tablename__ = "rides"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(50), ForeignKey("gucians.id"), nullable=False)
    pickup_location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)
    destination_location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)

    # Every ride belongs to a group, even if it's riding solo (group of 1).
    group_id = Column(Integer, ForeignKey("ride_groups.id"), nullable=True)

    status = Column(String(20), nullable=False, default="queued")

    is_priority = Column(Boolean, nullable=False, default=False)
    is_prebooked = Column(Boolean, nullable=False, default=False)
    scheduled_time = Column(DateTime(timezone=True), nullable=True)

    passenger_count = Column(Integer, nullable=False, default=1)

    verification_code = Column(String(10), nullable=True)
    verified_at = Column(DateTime(timezone=True), nullable=True)

    arrived_at = Column(DateTime(timezone=True), nullable=True)
    grace_expires_at = Column(DateTime(timezone=True), nullable=True)

    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    departure_deadline = Column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        CheckConstraint(
            "status IN ('queued','en_route','arrived','in_progress','completed','cancelled','no_show')",
            name="valid_ride_status"
        ),
    )

    user = relationship("Gucian", foreign_keys=[user_id])
    pickup_location = relationship("Location", foreign_keys=[pickup_location_id])
    destination_location = relationship("Location", foreign_keys=[destination_location_id])
    group = relationship("RideGroup", back_populates="rides", foreign_keys=[group_id])
    

class MedicalRequest(Base):
    __tablename__ = "medical_requests"

    id = Column(Integer, primary_key=True, index=True)
    gucian_id = Column(String(50), ForeignKey("gucians.id"), nullable=False)
    request_type = Column(String(20), nullable=False)  # 'injury' or 'disability'
    document_path = Column(String(255), nullable=False)
    status = Column(String(20), nullable=False, default="pending")  # pending/approved/rejected
    priority_days = Column(Integer, nullable=True)
    priority_until = Column(DateTime(timezone=True), nullable=True)
    reviewed_by = Column(Integer, ForeignKey("admin.id"), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        CheckConstraint("request_type IN ('injury','disability')", name="valid_request_type"),
        CheckConstraint("status IN ('pending','approved','rejected')", name="valid_request_status"),
    )

    gucian = relationship("Gucian", foreign_keys=[gucian_id])

class PasswordResetCode(Base):
    __tablename__ = "password_reset_codes"

    id = Column(Integer, primary_key=True, index=True)
    gucian_id = Column(String(50), ForeignKey("gucians.id"), nullable=False)
    code = Column(String(6), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    used = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class SendItem(Base):
    __tablename__ = "send_items"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(String(50), ForeignKey("gucians.id"), nullable=False)
    recipient_id = Column(String(50), ForeignKey("gucians.id"), nullable=True)
    pickup_location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)
    dropoff_location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)
    group_id = Column(Integer, ForeignKey("ride_groups.id"), nullable=True)
    item_description = Column(String(255), nullable=False)
    status = Column(String(20), nullable=False, default="pending")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    delivered_at = Column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        CheckConstraint(
            "status IN ('pending','queued','in_transit','delivered','cancelled')",
            name="valid_send_item_status"
        ),
    )

    sender = relationship("Gucian", foreign_keys=[sender_id])
    recipient = relationship("Gucian", foreign_keys=[recipient_id])
    pickup_location = relationship("Location", foreign_keys=[pickup_location_id])
    dropoff_location = relationship("Location", foreign_keys=[dropoff_location_id])

class Car(Base):
    __tablename__ = "cars"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    username = Column(String(100), unique=True, nullable=False)
    password = Column(String(255), nullable=False)
    status = Column(String(20), nullable=False, default="idle")
    current_lat = Column(Float, nullable=True)
    current_lng = Column(Float, nullable=True)
    current_group_id = Column(Integer, ForeignKey("ride_groups.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        CheckConstraint(
            "status IN ('idle','en_route','arrived','in_progress','offline')",
            name="valid_car_status"
        ),
    )
class RatingFeedback(Base):
    __tablename__ = "ratings_feedback"

    id = Column(Integer, primary_key=True, index=True)
    ride_id = Column(Integer, ForeignKey("rides.id"), unique=True, nullable=False)
    gucian_id = Column(String(50), ForeignKey("gucians.id"), nullable=False)
    stars = Column(Integer, nullable=False)
    smoothness = Column(Integer, nullable=True)
    punctuality = Column(Integer, nullable=True)
    cleanliness = Column(Integer, nullable=True)
    comment = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        CheckConstraint("stars BETWEEN 1 AND 5", name="valid_stars"),
        CheckConstraint("smoothness IS NULL OR smoothness BETWEEN 1 AND 5", name="valid_smoothness"),
        CheckConstraint("punctuality IS NULL OR punctuality BETWEEN 1 AND 5", name="valid_punctuality"),
        CheckConstraint("cleanliness IS NULL OR cleanliness BETWEEN 1 AND 5", name="valid_cleanliness"),
    )

    ride = relationship("Ride", foreign_keys=[ride_id])
    gucian = relationship("Gucian", foreign_keys=[gucian_id])