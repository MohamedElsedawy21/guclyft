from sqlalchemy.orm import Session
from fastapi import HTTPException, UploadFile
import models, schemas, auth
import random
import string
import os
import shutil
from datetime import datetime, timedelta, timezone

UPLOAD_DIR = "uploads/medical_docs"
os.makedirs(UPLOAD_DIR, exist_ok=True)

class PriorityHelper:
    @staticmethod
    def check_and_expire(gucian: models.Gucian, db: Session):
        """Auto-expire injury-based priority once its time window has passed."""
        if gucian.priority_until and gucian.priority_until < datetime.now(timezone.utc):
            gucian.is_priority = False
            gucian.priority_until = None
            db.commit()
            db.refresh(gucian)
        return gucian

class MedicalService:

    @staticmethod
    def submit_request(request_type: str, file: UploadFile, gucian: models.Gucian, db: Session):
        if request_type not in ("injury", "disability"):
            raise HTTPException(status_code=400, detail="request_type must be 'injury' or 'disability'")

        filename = f"{gucian.id}_{int(datetime.now().timestamp())}_{file.filename}"
        filepath = os.path.join(UPLOAD_DIR, filename)
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        new_request = models.MedicalRequest(
            gucian_id=gucian.id,
            request_type=request_type,
            document_path=filepath,
            status="pending",
        )
        db.add(new_request)
        db.commit()
        db.refresh(new_request)
        return new_request

    @staticmethod
    def get_my_requests(gucian: models.Gucian, db: Session):
        return db.query(models.MedicalRequest).filter(
            models.MedicalRequest.gucian_id == gucian.id
        ).order_by(models.MedicalRequest.created_at.desc()).all()

    @staticmethod
    def get_all_requests(db: Session, status_filter: str = None):
        query = db.query(models.MedicalRequest)
        if status_filter:
            query = query.filter(models.MedicalRequest.status == status_filter)
        results = query.order_by(models.MedicalRequest.created_at.desc()).all()

        views = []
        for r in results:
            views.append(schemas.MedicalRequestAdminView(
                id=r.id,
                gucian_id=r.gucian_id,
                gucian_name=f"{r.gucian.firstname} {r.gucian.lastname}",
                request_type=r.request_type,
                document_path=r.document_path,
                status=r.status,
                priority_days=r.priority_days,
                priority_until=r.priority_until,
                created_at=r.created_at,
            ))
        return views

    @staticmethod
    def review_request(request_id: int, review: schemas.MedicalRequestReview, admin: models.Admin, db: Session):
        req = db.query(models.MedicalRequest).filter(models.MedicalRequest.id == request_id).first()
        if not req:
            raise HTTPException(status_code=404, detail="Request not found")
        if req.status != "pending":
            raise HTTPException(status_code=400, detail="Request already reviewed")

        gucian = db.query(models.Gucian).filter(models.Gucian.id == req.gucian_id).first()

        req.status = review.status
        req.reviewed_by = admin.id
        req.reviewed_at = datetime.now(timezone.utc)

        if review.status == "approved":
            if req.request_type == "disability":
                gucian.is_priority = True
                gucian.priority_until = None  # permanent
                req.priority_until = None
            else:  # injury
                if not review.priority_days or review.priority_days < 1:
                    raise HTTPException(status_code=400, detail="priority_days is required to approve an injury request")
                until = datetime.now(timezone.utc) + timedelta(days=review.priority_days)
                gucian.is_priority = True
                gucian.priority_until = until
                req.priority_days = review.priority_days
                req.priority_until = until

        db.commit()
        db.refresh(req)
        return req


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
                    "is_priority": None,
                }
            raise HTTPException(status_code=401, detail="Invalid credentials")

        # check gucian
        gucian = db.query(models.Gucian).filter(models.Gucian.username == credentials.username).first()
        if gucian:
            if auth.verify_password(credentials.password, gucian.password):
                gucian = PriorityHelper.check_and_expire(gucian, db)
                token = auth.create_access_token({"sub": gucian.id, "role": "student"})
                return {
                    "token": token,
                    "role": "student",
                    "id": gucian.id,
                    "name": f"{gucian.firstname} {gucian.lastname}",
                    "is_priority": gucian.is_priority,
                }
            raise HTTPException(status_code=401, detail="Invalid credentials")

        raise HTTPException(status_code=401, detail="Invalid username or password")


class RideService:

    @staticmethod
    def book_ride(ride_data: schemas.RideCreate, current_gucian: models.Gucian, db: Session):
        current_gucian = PriorityHelper.check_and_expire(current_gucian, db)

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
            is_priority=current_gucian.is_priority,
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
        current_gucian = PriorityHelper.check_and_expire(current_gucian, db)

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
            is_priority=current_gucian.is_priority,
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


class AdminService:

    @staticmethod
    def get_all_gucians(db: Session):
        return db.query(models.Gucian).order_by(models.Gucian.createdat.desc()).all()



