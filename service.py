from sqlalchemy.orm import Session
from fastapi import HTTPException
import models, schemas, auth
import random
import string


class AuthService:

    @staticmethod
    def signup(user: schemas.GucianSignup, db: Session):
        existing = db.query(models.Gucian).filter(
            (models.Gucian.email == user.email) | (models.Gucian.username == user.username) | (models.Gucian.id == user.id)
        ).first()
        if existing:
            raise HTTPException(status_code=400, detail="Email or username already registered")

        new_user = models.Gucian(
            id=user.id,
            firstname=user.firstname,
            lastname=user.lastname,
            email=user.email,
            faculty=user.faculty,
            isinjured=user.isinjured,
            username=user.username,
            password=auth.hash_password(user.password),
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return {"message": "Signup successful"}

    @staticmethod
    def login(credentials: schemas.LoginRequest, db: Session):
        # check admin first
        admin = db.query(models.Admin).filter(models.Admin.username == credentials.username).first()
        if admin:
            if auth.verify_password(credentials.password, admin.password):
                token = auth.create_access_token({"sub": admin.username, "role": "admin"})
                return {
                    "token": token,
                    "role": "admin",
                    "id": str(admin.id),
                    "name": admin.name,
                    "isinjured": None,
                }
            raise HTTPException(status_code=401, detail="Invalid credentials")

        # check gucian
        gucian = db.query(models.Gucian).filter(models.Gucian.username == credentials.username).first()
        if gucian:
            if auth.verify_password(credentials.password, gucian.password):
                token = auth.create_access_token({"sub": gucian.id, "role": "student"})
                return {
                    "token": token,
                    "role": "student",
                    "id": gucian.id,
                    "name": f"{gucian.firstname} {gucian.lastname}",
                    "isinjured": gucian.isinjured,
                }
            raise HTTPException(status_code=401, detail="Invalid credentials")

        raise HTTPException(status_code=401, detail="Invalid username or password")


class RideService:

    @staticmethod
    def book_ride(ride_data: schemas.RideCreate, current_gucian: models.Gucian, db: Session):
        pickup = db.query(models.Location).filter(models.Location.id == ride_data.pickup_location_id).first()
        destination = db.query(models.Location).filter(models.Location.id == ride_data.destination_location_id).first()

        if not pickup or not destination:
            raise HTTPException(status_code=404, detail="Pickup or destination location not found")

        if pickup.id == destination.id:
            raise HTTPException(status_code=400, detail="Pickup and destination cannot be the same")

        verification_code = ''.join(random.choices(string.digits, k=4))

        new_ride = models.Ride(
            user_id=current_gucian.id,
            pickup_location_id=ride_data.pickup_location_id,
            destination_location_id=ride_data.destination_location_id,
            status="queued",
            is_priority=current_gucian.isinjured,
            is_prebooked=ride_data.is_prebooked,
            scheduled_time=ride_data.scheduled_time,
            passenger_count=ride_data.passenger_count,
            verification_code=verification_code,
        )

        db.add(new_ride)
        db.commit()
        db.refresh(new_ride)

        return new_ride

    @staticmethod
    def schedule_ride(ride_data: schemas.RideScheduleCreate, current_gucian: models.Gucian, db: Session):
        pickup = db.query(models.Location).filter(models.Location.id == ride_data.pickup_location_id).first()
        destination = db.query(models.Location).filter(models.Location.id == ride_data.destination_location_id).first()

        if not pickup or not destination:
            raise HTTPException(status_code=404, detail="Pickup or destination location not found")

        if pickup.id == destination.id:
            raise HTTPException(status_code=400, detail="Pickup and destination cannot be the same")

        verification_code = ''.join(random.choices(string.digits, k=4))

        new_ride = models.Ride(
            user_id=current_gucian.id,
            pickup_location_id=ride_data.pickup_location_id,
            destination_location_id=ride_data.destination_location_id,
            status="queued",
            is_priority=current_gucian.isinjured,
            is_prebooked=True,
            scheduled_time=ride_data.scheduled_time,
            passenger_count=ride_data.passenger_count,
            verification_code=verification_code,
        )

        db.add(new_ride)
        db.commit()
        db.refresh(new_ride)

        return new_ride

class LocationService:

    @staticmethod
    def get_all_locations(db: Session):
        return db.query(models.Location).order_by(models.Location.name).all()
