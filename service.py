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
from routing import graph, coords, get_route, distance_to_eta
from math import radians, sin, cos, sqrt, atan2 as _atan2  # if not already imported from routing

UPLOAD_DIR = "uploads/medical_docs"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Statuses that still count as "waiting to be served" (from shahoda's queue logic)
ACTIVE_STATUSES = ('queued', 'en_route', 'arrived', 'in_progress')

CAR_CAPACITY = 4

def _haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    dlat, dlon = radians(lat2 - lat1), radians(lon2 - lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1))*cos(radians(lat2))*sin(dlon/2)**2
    return 2 * R * atan2(sqrt(a), sqrt(1 - a))


class LiveTrackingService:

    @staticmethod
    def get_live_status(ride_id: int, gucian: models.Gucian, db: Session):
        ride = db.query(models.Ride).filter(models.Ride.id == ride_id).first()
        if not ride:
            raise HTTPException(status_code=404, detail="Ride not found")
        if ride.user_id != gucian.id:
            raise HTTPException(status_code=403, detail="This isn't your ride")

        pickup_row = db.execute(text("SELECT name FROM locations WHERE id = :id"), {"id": ride.pickup_location_id}).fetchone()
        dest_row = db.execute(text("SELECT name FROM locations WHERE id = :id"), {"id": ride.destination_location_id}).fetchone()

        pickup_name = pickup_row.name
        dest_name = dest_row.name
        pickup_coords = coords.get(pickup_name)
        dest_coords = coords.get(dest_name)

        car = None
        if ride.group_id:
            car = db.query(models.Car).filter(models.Car.current_group_id == ride.group_id).first()

        response = {
            "ride_id": ride.id,
            "status": ride.status,
            "pickup": {"name": pickup_name, "lat": pickup_coords[0], "lng": pickup_coords[1]} if pickup_coords else None,
            "destination": {"name": dest_name, "lat": dest_coords[0], "lng": dest_coords[1]} if dest_coords else None,
            "car": {"lat": car.current_lat, "lng": car.current_lng} if car and car.current_lat else None,
            "eta_minutes": None,
            "path": [],
            "grace_expires_at": ride.grace_expires_at,
            "departure_deadline": ride.departure_deadline,
            "verification_code": ride.verification_code,
        }

        if ride.status == "queued":
            if pickup_coords and dest_coords:
                result = get_route(graph, coords, pickup_name, dest_name)
                if result["path"]:
                    response["path"] = [list(coords[n]) for n in result["path"]]

        elif ride.status == "en_route":
            if car and car.current_lat and pickup_coords:
                response["path"] = [[car.current_lat, car.current_lng], list(pickup_coords)]
                dist = _haversine(car.current_lat, car.current_lng, pickup_coords[0], pickup_coords[1])
                response["eta_minutes"] = round(distance_to_eta(dist), 1)

        elif ride.status == "arrived":
            response["path"] = [list(pickup_coords)] if pickup_coords else []

        elif ride.status == "in_progress":
            if pickup_coords and dest_coords:
                result = get_route(graph, coords, pickup_name, dest_name)
                if result["path"]:
                    response["path"] = [list(coords[n]) for n in result["path"]]
                    response["eta_minutes"] = result["eta_minutes"]

        elif ride.status == "completed":
            response["path"] = []

        return response
    
def find_or_create_group(
    db: Session,
    pickup_location_id: int,
    destination_location_id: int,
    passenger_count: int,
    scheduled_time=None,
):
    """
    Carpool matching, run at request time (when a new ride is booked or scheduled).

    Live rides (scheduled_time=None) only match with other live, unmatched
    groups for the same pickup/destination.

    Scheduled rides only match with other scheduled rides for the same
    pickup/destination AND within a small time window of each other
    (default: 10 minutes) — so a 9:00am and 9:05am request can share a
    car, but a 9:00am and 2:00pm request won't.
    """
    TIME_WINDOW_MINUTES = 10

    query = db.query(models.RideGroup).filter(
        models.RideGroup.pickup_location_id == pickup_location_id,
        models.RideGroup.destination_location_id == destination_location_id,
        models.RideGroup.locked == False,
        models.RideGroup.passenger_total + passenger_count <= CAR_CAPACITY,
    )

    if scheduled_time is None:
        # live ride — only match groups whose rides are ALSO live (no scheduled_time)
        query = query.join(models.Ride, models.Ride.group_id == models.RideGroup.id).filter(
            models.Ride.scheduled_time.is_(None)
        )
    else:
        # scheduled ride — only match groups whose rides are scheduled within the time window
        window_start = scheduled_time - timedelta(minutes=TIME_WINDOW_MINUTES)
        window_end = scheduled_time + timedelta(minutes=TIME_WINDOW_MINUTES)
        query = query.join(models.Ride, models.Ride.group_id == models.RideGroup.id).filter(
            models.Ride.scheduled_time.isnot(None),
            models.Ride.scheduled_time >= window_start,
            models.Ride.scheduled_time <= window_end,
        )

    candidate = query.order_by(models.RideGroup.created_at.asc()).first()

    if candidate:
        candidate.passenger_total += passenger_count
        db.flush()
        return candidate

    new_group = models.RideGroup(
        pickup_location_id=pickup_location_id,
        destination_location_id=destination_location_id,
        passenger_total=passenger_count,
        locked=False,
    )
    db.add(new_group)
    db.flush()
    return new_group

def get_queue_position(db: Session, ride_id: int):
    """
    Returns (position, total_active) for a given ride.
    Position 1 = next up. Returns (None, total_active) if the ride
    is not currently active (e.g. already completed/cancelled).

    Ordering rule, now GROUP-aware: rides sharing a group_id are served
    together, so they occupy a single slot in the queue — that slot's
    position is based on the group's earliest-created active ride, and
    the group counts as "priority" if ANY active ride in it is priority.
    Groups/solo rides are then ordered priority-first, then by that
    earliest created_at (FIFO).
    """
    ride = db.execute(
        text("SELECT id, status, created_at, is_priority, group_id FROM rides WHERE id = :id"),
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

    group_stats = db.execute(
        text("""
            SELECT group_id,
                   MIN(created_at) AS group_created_at,
                   BOOL_OR(is_priority) AS group_is_priority
            FROM rides
            WHERE status = ANY(:statuses)
            GROUP BY group_id
        """),
        {"statuses": list(ACTIVE_STATUSES)}
    ).fetchall()

    this_group = next((g for g in group_stats if g.group_id == ride.group_id), None)
    if this_group is None:
        # Shouldn't happen (the ride itself is active), but guard anyway
        return None, total_active

    ahead_groups = 0
    for g in group_stats:
        if g.group_id == ride.group_id:
            continue
        if g.group_is_priority and not this_group.group_is_priority:
            ahead_groups += 1
        elif g.group_is_priority == this_group.group_is_priority and g.group_created_at < this_group.group_created_at:
            ahead_groups += 1

    return ahead_groups + 1, total_active

class GraceHelper:
    @staticmethod
    def check_and_expire_grace(car: models.Car, db: Session):
        if car.status != "arrived" or not car.current_group_id:
            return car

        rides = db.query(models.Ride).filter(models.Ride.group_id == car.current_group_id).all()
        if not rides:
            return car

        now = datetime.now(timezone.utc)
        grace_expires_at = rides[0].grace_expires_at
        if grace_expires_at and grace_expires_at.tzinfo is None:
            grace_expires_at = grace_expires_at.replace(tzinfo=timezone.utc)

        if grace_expires_at and grace_expires_at < now:
            for r in rides:
                if r.status == "arrived":
                    r.status = "no_show"

            car.status = "idle"
            car.current_group_id = None
            db.commit()
            db.refresh(car)

        return carv  

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

        # check car
        car = db.query(models.Car).filter(models.Car.username == credentials.username).first()
        if car:
            if auth.verify_password(credentials.password, car.password):
                token = auth.create_access_token({"sub": car.username, "role": "car"})
                return {
                    "token": token,
                    "role": "car",
                    "id": str(car.id),
                    "name": car.name,
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

        # Carpool matching: same pickup + same destination, room in the car.
        group = find_or_create_group(
            db,
            pickup_location_id=ride_data.pickup_location_id,
            destination_location_id=ride_data.destination_location_id,
            passenger_count=ride_data.passenger_count,
            scheduled_time=ride_data.scheduled_time,
        )
        new_ride = models.Ride(
            user_id=current_gucian.id,
            pickup_location_id=ride_data.pickup_location_id,
            destination_location_id=ride_data.destination_location_id,
            group_id=group.id,
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
            "group_id": new_ride.group_id,
            "group_size": group.passenger_total,
        }

    @staticmethod
    def get_active_ride(gucian: models.Gucian, db: Session):
        ride = (
            db.query(models.Ride)
            .filter(
                models.Ride.user_id == gucian.id,
                models.Ride.status.in_(["queued", "en_route", "arrived", "in_progress", "completed"]),
            )
            .order_by(models.Ride.created_at.desc())
            .first()
        )

        if not ride:
            return None

        now = datetime.now(timezone.utc)

        if ride.status == "completed":
            deadline = ride.departure_deadline
            if deadline and deadline.tzinfo is None:
                deadline = deadline.replace(tzinfo=timezone.utc)
            if not deadline or deadline < now:
                return None

        # scheduled rides only "go active" 5 minutes before their time
        if ride.is_prebooked and ride.scheduled_time and ride.status == "queued":
            sched = ride.scheduled_time
            if sched.tzinfo is None:
                sched = sched.replace(tzinfo=timezone.utc)
            if sched - now > timedelta(minutes=5):
                return None

        return ride
    
    @staticmethod
    def schedule_ride(ride_data: schemas.RideScheduleCreate, current_gucian: models.Gucian, db: Session):
        current_gucian = PriorityHelper.check_and_expire(current_gucian, db)

        if ride_data.pickup_location_id == ride_data.destination_location_id:
            raise HTTPException(status_code=400, detail="Pickup and destination cannot be the same")

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

        # Scheduled rides are grouped too, but only with OTHER scheduled rides
        # for the same pickup/destination/time — grouping with live "now" rides
        # wouldn't make sense since they're not happening at the same moment.
        # For now, treat each scheduled ride as its own group (size 1), same as
        # before, but with the group_id set so it flows through the same car
        # assignment logic later.
        group = find_or_create_group(
            db,
            pickup_location_id=ride_data.pickup_location_id,
            destination_location_id=ride_data.destination_location_id,
            passenger_count=ride_data.passenger_count,
        )

        new_ride = models.Ride(
            user_id=current_gucian.id,
            pickup_location_id=ride_data.pickup_location_id,
            destination_location_id=ride_data.destination_location_id,
            group_id=group.id,
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
            "group_id": new_ride.group_id,
            "group_size": group.passenger_total,
        }
    @staticmethod
    def cancel_ride(ride_id: int, gucian: models.Gucian, db: Session):
        ride = db.query(models.Ride).filter(models.Ride.id == ride_id).first()
        if not ride:
            raise HTTPException(status_code=404, detail="Ride not found")
        if ride.user_id != gucian.id:
            raise HTTPException(status_code=403, detail="This isn't your ride")

        if ride.status not in ("queued", "en_route"):
            raise HTTPException(
                status_code=400,
                detail="This ride can no longer be cancelled (car has arrived or trip already started)"
            )

        was_en_route = ride.status == "en_route"

        ride.status = "cancelled"
        ride.completed_at = datetime.now(timezone.utc)

        group = db.query(models.RideGroup).filter(models.RideGroup.id == ride.group_id).first()
        message = "Ride cancelled"

        if group:
            group.passenger_total = max(0, group.passenger_total - ride.passenger_count)

            other_active = db.query(models.Ride).filter(
                models.Ride.group_id == group.id,
                models.Ride.id != ride.id,
                models.Ride.status.in_(("queued", "en_route")),
            ).count()

            if other_active == 0:
                # this was the only rider left — free the car so it can grab its next ride
                if group.assigned_car_id:
                    car = db.query(models.Car).filter(models.Car.id == group.assigned_car_id).first()
                    if car and car.current_group_id == group.id:
                        car.status = "idle"
                        car.current_group_id = None
                group.locked = True
                message = "Ride cancelled — car freed up for its next ride"

            elif was_en_route and group.locked:
                # riders remain and a car is already en route — backfill the freed
                # seat(s) from the queue instead of leaving them empty for the trip.
                freed_seats = CAR_CAPACITY - group.passenger_total

                if freed_seats > 0:
                    backfill_candidates = (
                        db.query(models.Ride)
                        .filter(
                            models.Ride.status == "queued",
                            models.Ride.pickup_location_id == group.pickup_location_id,
                            models.Ride.destination_location_id == group.destination_location_id,
                            models.Ride.passenger_count <= freed_seats,
                        )
                        .order_by(models.Ride.is_priority.desc(), models.Ride.created_at.asc())
                        .all()
                    )

                    filled_names = []
                    for candidate in backfill_candidates:
                        if candidate.passenger_count > freed_seats:
                            continue

                        old_group = db.query(models.RideGroup).filter(
                            models.RideGroup.id == candidate.group_id
                        ).first()

                        candidate.group_id = group.id
                        candidate.status = "en_route"  # car is already en route to this pickup
                        group.passenger_total += candidate.passenger_count
                        freed_seats -= candidate.passenger_count

                        if old_group and old_group.id != group.id:
                            old_group.passenger_total = max(
                                0, old_group.passenger_total - candidate.passenger_count
                            )

                        filled_names.append(candidate.id)
                        if freed_seats <= 0:
                            break

                    if filled_names:
                        message = f"Ride cancelled — backfilled seat(s) with ride(s) {filled_names}"

        db.commit()
        db.refresh(ride)

        return {
            "ride_id": ride.id,
            "status": ride.status,
            "message": message,
        }

    @staticmethod
    def get_history(gucian: models.Gucian, db: Session):
        """Returns the gucian's past rides (completed/cancelled/no_show), newest first,
        each with its rating attached if one exists."""
        rides = (
            db.query(models.Ride)
            .filter(
                models.Ride.user_id == gucian.id,
                models.Ride.status.in_(["completed", "cancelled", "no_show"]),
            )
            .order_by(models.Ride.created_at.desc())
            .all()
        )
 
        if not rides:
            return []
 
        ride_ids = [r.id for r in rides]
        ratings = {
            r.ride_id: r
            for r in db.query(models.RatingFeedback)
            .filter(models.RatingFeedback.ride_id.in_(ride_ids))
            .all()
        }
 
        history = []
        for ride in rides:
            history.append(
                schemas.RideHistoryItem(
                    ride_id=ride.id,
                    status=ride.status,
                    pickup_name=ride.pickup_location.name,
                    destination_name=ride.destination_location.name,
                    created_at=ride.created_at,
                    completed_at=ride.completed_at,
                    rating=ratings.get(ride.id),
                )
            )
        return history
    
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

        # Items don't take up passenger seats, so pass 0 for capacity purposes —
        # they join any live (non-scheduled) group matching pickup/destination.
        group = find_or_create_group(
            db,
            pickup_location_id=item_data.pickup_location_id,
            destination_location_id=item_data.dropoff_location_id,
            passenger_count=0,
        )

        new_item = models.SendItem(
            sender_id=sender.id,
            recipient_id=item_data.recipient_id,
            pickup_location_id=item_data.pickup_location_id,
            dropoff_location_id=item_data.dropoff_location_id,
            group_id=group.id,
            item_description=item_data.item_description,
            status="queued",
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
        if item.status not in ("queued",):
            raise HTTPException(status_code=400, detail="This item can no longer be cancelled")

        item.status = "cancelled"

        if item.group_id:
            group = db.query(models.RideGroup).filter(models.RideGroup.id == item.group_id).first()
            # items don't count toward passenger_total, so nothing to decrement there

        db.commit()
        db.refresh(item)
        return item

    @staticmethod
    def get_active_item(gucian: models.Gucian, db: Session):
        item = (
            db.query(models.SendItem)
            .filter(
                models.SendItem.sender_id == gucian.id,
                models.SendItem.status.in_(["queued", "in_transit"]),
            )
            .order_by(models.SendItem.created_at.desc())
            .first()
        )
        return item
    
class CarService:

    @staticmethod
    def get_next_ride(car: models.Car, db: Session):
        car = GraceHelper.check_and_expire_grace(car, db)
        if car.status != "idle":
            raise HTTPException(status_code=400, detail="Car is not idle")

        ride_group_ids = db.query(models.Ride.group_id).filter(models.Ride.status == "queued")
        item_group_ids = db.query(models.SendItem.group_id).filter(models.SendItem.status == "queued")
        candidate_group_ids = ride_group_ids.union(item_group_ids).subquery()

        next_group = (
            db.query(models.RideGroup)
            .filter(models.RideGroup.id.in_(db.query(candidate_group_ids)))
            .filter(models.RideGroup.assigned_car_id.is_(None))
            .order_by(models.RideGroup.created_at.asc())  # simple FIFO across groups now
            .first()
        )

        if not next_group:
            return {"message": "No rides in queue"}

        next_group.assigned_car_id = car.id
        next_group.locked = True
        car.current_group_id = next_group.id
        car.status = "en_route"

        rides = db.query(models.Ride).filter(models.Ride.group_id == next_group.id, models.Ride.status == "queued").all()
        for r in rides:
            r.status = "en_route"

        items = db.query(models.SendItem).filter(models.SendItem.group_id == next_group.id, models.SendItem.status == "queued").all()

        db.commit()
        db.refresh(next_group)

        return {
            "group_id": next_group.id,
            "pickup_location_id": next_group.pickup_location_id,
            "destination_location_id": next_group.destination_location_id,
            "passenger_total": next_group.passenger_total,
            "ride_ids": [r.id for r in rides],
            "item_ids": [i.id for i in items],
        }
    @staticmethod
    def mark_arrived(car: models.Car, db: Session):
        if car.status != "en_route" or not car.current_group_id:
            raise HTTPException(status_code=400, detail="Car has no active trip to mark as arrived")

        rides = db.query(models.Ride).filter(models.Ride.group_id == car.current_group_id).all()
        items = db.query(models.SendItem).filter(
            models.SendItem.group_id == car.current_group_id,
            models.SendItem.status == "queued",
        ).all()

        now = datetime.now(timezone.utc)
        for r in rides:
            r.status = "arrived"
            r.arrived_at = now
            r.grace_expires_at = now + timedelta(minutes=3)

        for i in items:
            i.status = "in_transit"

        car.status = "arrived"
        db.commit()
        return {"message": "Marked as arrived", "grace_expires_at": now + timedelta(minutes=3)}
    
    @staticmethod
    def complete_ride(car: models.Car, db: Session):
        if not car.current_group_id:
            raise HTTPException(status_code=400, detail="Car has no active trip")

        rides = db.query(models.Ride).filter(models.Ride.group_id == car.current_group_id).all()
        items = db.query(models.SendItem).filter(
            models.SendItem.group_id == car.current_group_id,
            models.SendItem.status == "in_transit",
        ).all()

        now = datetime.now(timezone.utc)
        deadline = now + timedelta(seconds=90)
        for r in rides:
            r.status = "completed"
            r.completed_at = now
            r.departure_deadline = deadline

        for i in items:
            i.status = "delivered"
            i.delivered_at = now

        group = db.query(models.RideGroup).filter(models.RideGroup.id == car.current_group_id).first()

        car.status = "idle"
        car.current_group_id = None
        db.commit()

        return {"message": "Ride completed", "group_id": group.id, "departure_deadline": deadline}

    @staticmethod
    def update_location(car: models.Car, lat: float, lng: float, db: Session):
        car.current_lat = lat
        car.current_lng = lng
        db.commit()
        return {"message": "Location updated"}

class VerificationService:

    @staticmethod
    def verify_code(ride_id: int, code: str, car: models.Car, db: Session):
        ride = db.query(models.Ride).filter(models.Ride.id == ride_id).first()
        if not ride:
            raise HTTPException(status_code=404, detail="Ride not found")

        if ride.group_id != car.current_group_id:
            raise HTTPException(status_code=403, detail="This ride isn't part of your current trip")

        if ride.status == "no_show":
            raise HTTPException(status_code=400, detail="Grace period expired — ride marked as no-show")

        if ride.status != "arrived":
            raise HTTPException(status_code=400, detail="Ride is not ready for verification")

        now = datetime.now(timezone.utc)
        grace_expires_at = ride.grace_expires_at
        if grace_expires_at and grace_expires_at.tzinfo is None:
            grace_expires_at = grace_expires_at.replace(tzinfo=timezone.utc)

        if grace_expires_at and grace_expires_at < now:
            ride.status = "no_show"
            db.commit()
            raise HTTPException(status_code=400, detail="Grace period expired — ride marked as no-show")

        if ride.verification_code != code:
            raise HTTPException(status_code=400, detail="Incorrect verification code")

        ride.verified_at = now
        db.commit()

        # check if every ride in this group has now been verified
        group_rides = db.query(models.Ride).filter(models.Ride.group_id == ride.group_id).all()
        still_waiting = [r for r in group_rides if r.status == "arrived" and r.verified_at is None]

        if not still_waiting:
            for r in group_rides:
                if r.status == "arrived":
                    r.status = "in_progress"
                    r.started_at = now
            car.status = "in_progress"
            db.commit()

        db.refresh(ride)
        return {
            "ride_id": ride.id,
            "verified": True,
            "all_verified": not still_waiting,
            "still_waiting_ride_ids": [r.id for r in still_waiting],
        }
class RatingService:

    @staticmethod
    def submit_rating(ride_id: int, rating_data: schemas.RatingCreate, gucian: models.Gucian, db: Session):
        ride = db.query(models.Ride).filter(models.Ride.id == ride_id).first()
        if not ride:
            raise HTTPException(status_code=404, detail="Ride not found")
        if ride.user_id != gucian.id:
            raise HTTPException(status_code=403, detail="This isn't your ride")
        if ride.status != "completed":
            raise HTTPException(status_code=400, detail="Only completed rides can be rated")

        existing = db.query(models.RatingFeedback).filter(models.RatingFeedback.ride_id == ride_id).first()
        if existing:
            raise HTTPException(status_code=400, detail="This ride has already been rated")

        new_rating = models.RatingFeedback(
            ride_id=ride_id,
            gucian_id=gucian.id,
            stars=rating_data.stars,
            smoothness=rating_data.smoothness,
            punctuality=rating_data.punctuality,
            cleanliness=rating_data.cleanliness,
            comment=rating_data.comment,
        )
        db.add(new_rating)
        db.commit()
        db.refresh(new_rating)
        return new_rating

    @staticmethod
    def get_for_ride(ride_id: int, gucian: models.Gucian, db: Session):
        ride = db.query(models.Ride).filter(models.Ride.id == ride_id).first()
        if not ride or ride.user_id != gucian.id:
            raise HTTPException(status_code=404, detail="Ride not found")

        rating = db.query(models.RatingFeedback).filter(models.RatingFeedback.ride_id == ride_id).first()
        return rating  # may be None — frontend treats that as "not yet rated"

    @staticmethod
    def get_all_for_admin(db: Session):
        ratings = db.query(models.RatingFeedback).order_by(models.RatingFeedback.created_at.desc()).all()
        return [
            schemas.RatingAdminView(
                id=r.id,
                ride_id=r.ride_id,
                gucian_name=f"{r.gucian.firstname} {r.gucian.lastname}",
                stars=r.stars,
                smoothness=r.smoothness,
                punctuality=r.punctuality,
                cleanliness=r.cleanliness,
                comment=r.comment,
                created_at=r.created_at,
            )
            for r in ratings
        ]

    @staticmethod
    def get_summary(db: Session):
        result = db.execute(text("""
            SELECT
                COUNT(*) as total,
                AVG(stars) as avg_stars,
                AVG(smoothness) as avg_smoothness,
                AVG(punctuality) as avg_punctuality,
                AVG(cleanliness) as avg_cleanliness
            FROM ratings_feedback
        """)).fetchone()

        return {
            "total_ratings": result.total or 0,
            "average_stars": round(result.avg_stars, 2) if result.avg_stars else None,
            "average_smoothness": round(result.avg_smoothness, 2) if result.avg_smoothness else None,
            "average_punctuality": round(result.avg_punctuality, 2) if result.avg_punctuality else None,
            "average_cleanliness": round(result.avg_cleanliness, 2) if result.avg_cleanliness else None,
        }

class SendItemLiveService:

    @staticmethod
    def get_live_status(item_id: int, gucian: models.Gucian, db: Session):
        item = db.query(models.SendItem).filter(models.SendItem.id == item_id).first()
        if not item:
            raise HTTPException(status_code=404, detail="Item not found")
        if item.sender_id != gucian.id and item.recipient_id != gucian.id:
            raise HTTPException(status_code=403, detail="This isn't your item")

        pickup_row = db.execute(text("SELECT name FROM locations WHERE id = :id"), {"id": item.pickup_location_id}).fetchone()
        dropoff_row = db.execute(text("SELECT name FROM locations WHERE id = :id"), {"id": item.dropoff_location_id}).fetchone()

        pickup_name = pickup_row.name
        dropoff_name = dropoff_row.name
        pickup_coords = coords.get(pickup_name)
        dropoff_coords = coords.get(dropoff_name)

        car = None
        if item.group_id:
            car = db.query(models.Car).filter(models.Car.current_group_id == item.group_id).first()

        response = {
            "item_id": item.id,
            "status": item.status,
            "item_description": item.item_description,
            "pickup": {"name": pickup_name, "lat": pickup_coords[0], "lng": pickup_coords[1]} if pickup_coords else None,
            "dropoff": {"name": dropoff_name, "lat": dropoff_coords[0], "lng": dropoff_coords[1]} if dropoff_coords else None,
            "car": {"lat": car.current_lat, "lng": car.current_lng} if car and car.current_lat else None,
            "path": [],
        }

        if item.status == "queued":
            if pickup_coords and dropoff_coords:
                result = get_route(graph, coords, pickup_name, dropoff_name)
                if result["path"]:
                    response["path"] = [list(coords[n]) for n in result["path"]]

        elif item.status == "in_transit":
            if pickup_coords and dropoff_coords:
                result = get_route(graph, coords, pickup_name, dropoff_name)
                if result["path"]:
                    response["path"] = [list(coords[n]) for n in result["path"]]

        return response

class ActiveStatusService:

    @staticmethod
    def get_active(gucian: models.Gucian, db: Session):
        ride = RideService.get_active_ride(gucian, db)
        if ride:
            return {"active": True, "type": "ride", "id": ride.id, "status": ride.status}

        item = SendItemService.get_active_item(gucian, db)
        if item:
            return {"active": True, "type": "item", "id": item.id, "status": item.status}

        return {"active": False}
