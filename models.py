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
    isinjured = Column(Boolean, default=False)
    username = Column(String(100), nullable=False)
    password = Column(String(100), nullable=False)
    createdat = Column(DateTime(timezone=True), server_default=func.now())


class Location(Base):
    __tablename__ = "locations"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)


class Ride(Base):
    __tablename__ = "rides"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(50), ForeignKey("gucians.id"), nullable=False)
    pickup_location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)
    destination_location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)

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

    __table_args__ = (
        CheckConstraint(
            "status IN ('queued','en_route','arrived','in_progress','completed','cancelled','no_show')",
            name="valid_ride_status"
        ),
    )

    user = relationship("Gucian", foreign_keys=[user_id])
    pickup_location = relationship("Location", foreign_keys=[pickup_location_id])
    destination_location = relationship("Location", foreign_keys=[destination_location_id])