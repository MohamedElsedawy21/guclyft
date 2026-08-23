from sqlalchemy.orm import Session
from sqlalchemy import text
from fastapi import HTTPException, UploadFile
import models, schemas, auth
import random
import string
import os
import shutil
import random
from datetime import datetime, timedelta, timezone
from fastapi_mail import FastMail, MessageSchema, MessageType
from config import mail_config
from datetime import datetime, timedelta, timezone
from routing import graph, coords, get_route

UPLOAD_DIR = "uploads/medical_docs"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Statuses that still count as "waiting to be served" (from shahoda's queue logic)
ACTIVE_STATUSES = ('queued', 'en_route', 'arrived', 'in_progress')


def get_queue_position(db: Session, ride_id: int):
    """
    Returns (position, total_active) for a given ride.
    Position 1 = next up. Returns (None, total_active) if the ride
    is not currently active (e.g. already completed/cancelled).

    Ordering rule: priority rides are always served before normal rides,
    regardless of creation time. Within the same priority tier, earlier
    created_at goes first (FIFO).
    """
    ride = db.execute(
        text("SELECT id, status, created_at, is_priority FROM rides WHERE id = :id"),
        {"id": ride_id}
    ).fetchone()

    if ride is None:
        return None, None

    total_active = db.execute(
        text("SELECT COUNT(*) as c FROM rides WHERE status = ANY(:statuses)"),
        {"statuses": list(ACTIVE_STATUSES)}
    ).fetchone().c

    if ride.status not in ACTIVE_STATUSES:
        return None, total_active

    if ride.is_priority:
        ahead_count = db.execute(
            text("""
                SELECT COUNT(*) as c FROM rides
                WHERE status = ANY(:statuses)
                AND is_priority = TRUE
                AND created_at < :created_at
            """),
            {"statuses": list(ACTIVE_STATUSES), "created_at": ride.created_at}
        ).fetchone().c
    else:
        ahead_count = db.execute(
            text("""
                SELECT COUNT(*) as c FROM rides
                WHERE status = ANY(:statuses)
                AND (
                    is_priority = TRUE
                    OR created_at < :created_at
                )
            """),
            {"statuses": list(ACTIVE_STATUSES), "created_at": ride.created_at}
        ).fetchone().c

    return ahead_count + 1, total_active

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

        if ride_data.pickup_location_id == ride_data.destination_location_id:
            raise HTTPException(status_code=400, detail="Pickup and destination cannot be the same")

        # Look up names from the IDs the frontend already sends — one extra
        # SELECT each for pickup and dropoff — then hand those names to get_route().
        pickup_row = db.execute(
            text("SELECT name FROM locations WHERE id = :id"),
            {"id": ride_data.pickup_location_id}
        ).fetchone()
        dropoff_row = db.execute(
            text("SELECT name FROM locations WHERE id = :id"),
            {"id": ride_data.destination_location_id}
        ).fetchone()

        if pickup_row is None:
            raise HTTPException(status_code=404, detail="Pickup location not found")
        if dropoff_row is None:
            raise HTTPException(status_code=404, detail="Destination location not found")

        pickup_name = pickup_row.name
        dropoff_name = dropoff_row.name

        if pickup_name not in graph:
            raise HTTPException(status_code=400, detail=f"Location '{pickup_name}' exists but has no route data")
        if dropoff_name not in graph:
            raise HTTPException(status_code=400, detail=f"Location '{dropoff_name}' exists but has no route data")

        route_result = get_route(graph, coords, pickup_name, dropoff_name)
        if route_result["path"] is None:
            raise HTTPException(
                status_code=400,
                detail=f"No route found between '{pickup_name}' and '{dropoff_name}'"
            )

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

        position, total_active = get_queue_position(db, new_ride.id)

        return {
            "id": new_ride.id,
            "user_id": new_ride.user_id,
            "pickup_location_id": new_ride.pickup_location_id,
            "destination_location_id": new_ride.destination_location_id,
            "status": new_ride.status,
            "is_priority": new_ride.is_priority,
            "is_prebooked": new_ride.is_prebooked,
            "scheduled_time": new_ride.scheduled_time,
            "passenger_count": new_ride.passenger_count,
            "verification_code": new_ride.verification_code,
            "created_at": new_ride.created_at,
            "route": route_result,
            "queue_position": position,
            "total_active_rides": total_active,
        }

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


class PasswordResetService:

    @staticmethod
    async def request_reset(email: str, db: Session):
        gucian = db.query(models.Gucian).filter(models.Gucian.email == email).first()
        if not gucian:
            # Don't reveal whether the email exists — respond the same either way
            return {"message": "If that email is registered, a code has been sent."}

        code = ''.join(random.choices(string.digits, k=6))
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)

        reset_entry = models.PasswordResetCode(
            gucian_id=gucian.id,
            code=code,
            expires_at=expires_at,
        )
        db.add(reset_entry)
        db.commit()

        message = MessageSchema(
            subject="GUCLYFT Password Reset Code",
            recipients=[email],
            body=f"Your GUCLYFT password reset code is: {code}\n\nThis code expires in 10 minutes.",
            subtype=MessageType.plain,
        )
        fm = FastMail(mail_config)
        await fm.send_message(message)

        return {"message": "If that email is registered, a code has been sent."}

    @staticmethod
    def verify_code(email: str, code: str, db: Session):
        gucian = db.query(models.Gucian).filter(models.Gucian.email == email).first()
        if not gucian:
            raise HTTPException(status_code=400, detail="Invalid code")

        entry = db.query(models.PasswordResetCode).filter(
            models.PasswordResetCode.gucian_id == gucian.id,
            models.PasswordResetCode.code == code,
            models.PasswordResetCode.used == False,
        ).order_by(models.PasswordResetCode.created_at.desc()).first()

        if not entry or entry.expires_at < datetime.now(timezone.utc):
            raise HTTPException(status_code=400, detail="Invalid or expired code")

        entry.used = True
        db.commit()

        reset_token = auth.create_reset_token(gucian.id)
        return {"reset_token": reset_token}

    @staticmethod
    def reset_password(reset_token: str, new_password: str, db: Session):
        gucian_id = auth.verify_reset_token(reset_token)
        gucian = db.query(models.Gucian).filter(models.Gucian.id == gucian_id).first()
        if not gucian:
            raise HTTPException(status_code=404, detail="User not found")

        gucian.password = auth.hash_password(new_password)
        db.commit()
        return {"message": "Password reset successful"}

class SendItemService:

    @staticmethod
    def create(item_data: schemas.SendItemCreate, sender: models.Gucian, db: Session):
        pickup = db.query(models.Location).filter(models.Location.id == item_data.pickup_location_id).first()
        dropoff = db.query(models.Location).filter(models.Location.id == item_data.dropoff_location_id).first()

        if not pickup or not dropoff:
            raise HTTPException(status_code=404, detail="Pickup or dropoff location not found")
        if pickup.id == dropoff.id:
            raise HTTPException(status_code=400, detail="Pickup and dropoff cannot be the same")

        if item_data.recipient_id:
            recipient = db.query(models.Gucian).filter(models.Gucian.id == item_data.recipient_id).first()
            if not recipient:
                raise HTTPException(status_code=404, detail="Recipient not found")

        new_item = models.SendItem(
            sender_id=sender.id,
            recipient_id=item_data.recipient_id,
            pickup_location_id=item_data.pickup_location_id,
            dropoff_location_id=item_data.dropoff_location_id,
            item_description=item_data.item_description,
            status="pending",
        )
        db.add(new_item)
        db.commit()
        db.refresh(new_item)
        return new_item

    @staticmethod
    def get_my_items(gucian: models.Gucian, db: Session):
        return db.query(models.SendItem).filter(
            (models.SendItem.sender_id == gucian.id) | (models.SendItem.recipient_id == gucian.id)
        ).order_by(models.SendItem.created_at.desc()).all()

    @staticmethod
    def cancel(item_id: int, gucian: models.Gucian, db: Session):
        item = db.query(models.SendItem).filter(models.SendItem.id == item_id).first()
        if not item:
            raise HTTPException(status_code=404, detail="Item not found")
        if item.sender_id != gucian.id:
            raise HTTPException(status_code=403, detail="You can only cancel your own requests")
        if item.status != "pending":
            raise HTTPException(status_code=400, detail="Only pending items can be cancelled")

        item.status = "cancelled"
        db.commit()
        db.refresh(item)
        return item