from fastapi import FastAPI, HTTPException, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime, timezone

from routing import graph, coords, get_route
from database import get_db

app = FastAPI(title="GUC Ride Routing API")

# Statuses that still count as "waiting to be served"
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
        # Only earlier priority rides are ahead of a priority ride
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
        # All priority rides are ahead, plus earlier normal rides
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


@app.get("/")
def root():
    return {"message": "GUC Ride Routing API is running"}


# ---- Routing endpoints (no database involved) ----

@app.get("/gates")
def list_gates():
    """Gate names known to the routing engine (used for computing routes)."""
    return {"gates": list(coords.keys())}


@app.get("/route")
def route(from_gate: str, to_gate: str):
    if from_gate not in graph:
        raise HTTPException(status_code=404, detail=f"Unknown gate: '{from_gate}'")
    if to_gate not in graph:
        raise HTTPException(status_code=404, detail=f"Unknown gate: '{to_gate}'")

    result = get_route(graph, coords, from_gate, to_gate)

    if result["path"] is None:
        raise HTTPException(status_code=400, detail=f"No route found between '{from_gate}' and '{to_gate}'")

    return result


# ---- Database-backed endpoints ----

@app.get("/locations")
def list_locations(db: Session = Depends(get_db)):
    """Returns all locations from the database — used to populate the dropdown."""
    result = db.execute(text("SELECT id, name FROM locations ORDER BY name"))
    return [{"id": row.id, "name": row.name} for row in result]


@app.post("/request-ride")
def request_ride(user_id: str, pickup_gate: str, dropoff_gate: str, db: Session = Depends(get_db)):
    # 0. Look up the requesting user's current priority status
    user_row = db.execute(
        text("SELECT id, is_priority, priority_until FROM gucians WHERE id = :id"),
        {"id": user_id}
    ).fetchone()

    if user_row is None:
        raise HTTPException(status_code=404, detail=f"Unknown user_id: '{user_id}'")

    is_priority_now = bool(user_row.is_priority) and (
        user_row.priority_until is None or user_row.priority_until > datetime.now(timezone.utc)
    )

    # 1. Look up location IDs for the given gate names
    pickup_row = db.execute(
        text("SELECT id FROM locations WHERE name = :name"), {"name": pickup_gate}
    ).fetchone()
    dropoff_row = db.execute(
        text("SELECT id FROM locations WHERE name = :name"), {"name": dropoff_gate}
    ).fetchone()

    if pickup_row is None:
        raise HTTPException(status_code=404, detail=f"Unknown pickup location: '{pickup_gate}'")
    if dropoff_row is None:
        raise HTTPException(status_code=404, detail=f"Unknown dropoff location: '{dropoff_gate}'")

    pickup_location_id = pickup_row.id
    dropoff_location_id = dropoff_row.id

    # 2. Compute the route using our existing routing logic
    if pickup_gate not in graph or dropoff_gate not in graph:
        raise HTTPException(status_code=400, detail="Gate exists in database but not in routing graph")

    route_result = get_route(graph, coords, pickup_gate, dropoff_gate)
    if route_result["path"] is None:
        raise HTTPException(status_code=400, detail=f"No route found between '{pickup_gate}' and '{dropoff_gate}'")

    # 3. Insert the new ride (status defaults to 'queued' automatically)
    insert_result = db.execute(
        text("""
            INSERT INTO rides (user_id, pickup_location_id, destination_location_id, is_priority)
            VALUES (:user_id, :pickup_id, :dropoff_id, :is_priority)
            RETURNING id, status, created_at, is_priority
        """),
        {
            "user_id": user_id,
            "pickup_id": pickup_location_id,
            "dropoff_id": dropoff_location_id,
            "is_priority": is_priority_now,
        },
    )
    new_ride = insert_result.fetchone()
    db.commit()

    # 4. Compute where this ride currently sits in the queue
    position, total_active = get_queue_position(db, new_ride.id)

    # 5. Return ride info + route info + queue position together
    return {
        "ride_id": new_ride.id,
        "status": new_ride.status,
        "created_at": new_ride.created_at,
        "is_priority": new_ride.is_priority,
        "route": route_result,
        "queue_position": position,
        "total_active_rides": total_active,
    }


@app.get("/rides/{ride_id}")
def get_ride(ride_id: int, db: Session = Depends(get_db)):
    result = db.execute(
        text("SELECT * FROM rides WHERE id = :id"), {"id": ride_id}
    ).fetchone()

    if result is None:
        raise HTTPException(status_code=404, detail=f"Ride {ride_id} not found")

    return dict(result._mapping)


@app.get("/rides/{ride_id}/queue-position")
def ride_queue_position(ride_id: int, db: Session = Depends(get_db)):
    ride_exists = db.execute(
        text("SELECT id FROM rides WHERE id = :id"), {"id": ride_id}
    ).fetchone()
    if ride_exists is None:
        raise HTTPException(status_code=404, detail=f"Ride {ride_id} not found")

    position, total_active = get_queue_position(db, ride_id)

    return {
        "ride_id": ride_id,
        "queue_position": position,  # null means this ride is no longer active
        "total_active_rides": total_active,
    }