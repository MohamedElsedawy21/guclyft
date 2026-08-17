from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from database import engine, SessionLocal, Base
import models, schemas
from service import AuthService
from service import RideService
import auth
from database import get_db
from service import LocationService

Base.metadata.create_all(bind=engine)

app = FastAPI()

@app.post("/signup")
def signup(user: schemas.GucianSignup, db: Session = Depends(get_db)):
    return AuthService.signup(user, db)

@app.post("/login", response_model=schemas.LoginResponse)
def login(credentials: schemas.LoginRequest, db: Session = Depends(get_db)):
    return AuthService.login(credentials, db)

@app.post("/rides/book", response_model=schemas.RideResponse)
def book_ride(
    ride_data: schemas.RideCreate,
    current_gucian: models.Gucian = Depends(auth.get_current_gucian),
    db: Session = Depends(get_db),
):
    return RideService.book_ride(ride_data, current_gucian, db)

@app.post("/rides/schedule", response_model=schemas.RideResponse)
def schedule_ride(
    ride_data: schemas.RideScheduleCreate,
    current_gucian: models.Gucian = Depends(auth.get_current_gucian),
    db: Session = Depends(get_db),
):
    return RideService.schedule_ride(ride_data, current_gucian, db)

@app.get("/locations", response_model=list[schemas.LocationResponse])
def get_locations(db: Session = Depends(get_db)):
    return LocationService.get_all_locations(db)