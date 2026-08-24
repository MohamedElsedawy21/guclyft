from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from database import engine, SessionLocal, Base
import models, schemas
from service import AuthService
from service import RideService
import auth
from database import get_db
from service import LocationService
from service import AdminService
from fastapi import UploadFile, File, Form
from service import MedicalService
from fastapi.responses import FileResponse
from jose import jwt, JWTError
from config import SECRET_KEY
from auth import ALGORITHM
from service import PasswordResetService
from service import SendItemService
from service import CarService
from service import VerificationService

Base.metadata.create_all(bind=engine)

app = FastAPI()

@app.post("/signup")
def signup(user: schemas.GucianSignup, db: Session = Depends(get_db)):
    return AuthService.signup(user, db)

@app.post("/login", response_model=schemas.LoginResponse)
def login(credentials: schemas.LoginRequest, db: Session = Depends(get_db)):
    return AuthService.login(credentials, db)

@app.post("/rides/book", response_model=schemas.RideBookResponse)
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


@app.get("/admin/gucians", response_model=list[schemas.GucianAdminView])
def get_all_gucians(
    current_admin: models.Admin = Depends(auth.get_current_admin),
    db: Session = Depends(get_db),
):
    return AdminService.get_all_gucians(db)

@app.post("/medical-requests", response_model=schemas.MedicalRequestResponse)
def submit_medical_request(
    request_type: str = Form(...),
    file: UploadFile = File(...),
    current_gucian: models.Gucian = Depends(auth.get_current_gucian),
    db: Session = Depends(get_db),
):
    return MedicalService.submit_request(request_type, file, current_gucian, db)


@app.get("/medical-requests/me", response_model=list[schemas.MedicalRequestResponse])
def get_my_medical_requests(
    current_gucian: models.Gucian = Depends(auth.get_current_gucian),
    db: Session = Depends(get_db),
):
    return MedicalService.get_my_requests(current_gucian, db)


@app.get("/admin/medical-requests", response_model=list[schemas.MedicalRequestAdminView])
def get_all_medical_requests(
    status: str = None,
    current_admin: models.Admin = Depends(auth.get_current_admin),
    db: Session = Depends(get_db),
):
    return MedicalService.get_all_requests(db, status_filter=status)


@app.put("/admin/medical-requests/{request_id}/review", response_model=schemas.MedicalRequestResponse)
def review_medical_request(
    request_id: int,
    review: schemas.MedicalRequestReview,
    current_admin: models.Admin = Depends(auth.get_current_admin),
    db: Session = Depends(get_db),
):
    return MedicalService.review_request(request_id, review, current_admin, db)


@app.get("/admin/medical-requests/{request_id}/document")
def get_medical_document(request_id: int, token: str, db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("role") != "admin":
            raise HTTPException(status_code=403, detail="Forbidden")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    req = db.query(models.MedicalRequest).filter(models.MedicalRequest.id == request_id).first()
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")

    return FileResponse(req.document_path)

@app.post("/forgot-password")
async def forgot_password(request: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    return await PasswordResetService.request_reset(request.email, db)


@app.post("/verify-reset-code")
def verify_reset_code(request: schemas.VerifyResetCodeRequest, db: Session = Depends(get_db)):
    return PasswordResetService.verify_code(request.email, request.code, db)


@app.post("/reset-password")
def reset_password(request: schemas.ResetPasswordRequest, db: Session = Depends(get_db)):
    return PasswordResetService.reset_password(request.reset_token, request.new_password, db)

@app.post("/send-items", response_model=schemas.SendItemResponse)
def create_send_item(
    item_data: schemas.SendItemCreate,
    current_gucian: models.Gucian = Depends(auth.get_current_gucian),
    db: Session = Depends(get_db),
):
    return SendItemService.create(item_data, current_gucian, db)


@app.get("/send-items/mine", response_model=list[schemas.SendItemResponse])
def get_my_send_items(
    current_gucian: models.Gucian = Depends(auth.get_current_gucian),
    db: Session = Depends(get_db),
):
    return SendItemService.get_my_items(current_gucian, db)


@app.put("/send-items/{item_id}/cancel", response_model=schemas.SendItemResponse)
def cancel_send_item(
    item_id: int,
    current_gucian: models.Gucian = Depends(auth.get_current_gucian),
    db: Session = Depends(get_db),
):
    return SendItemService.cancel(item_id, current_gucian, db)

@app.post("/cars/next-ride")
def get_next_ride(current_car: models.Car = Depends(auth.get_current_car), db: Session = Depends(get_db)):
    return CarService.get_next_ride(current_car, db)

@app.put("/cars/arrived")
def mark_arrived(current_car: models.Car = Depends(auth.get_current_car), db: Session = Depends(get_db)):
    return CarService.mark_arrived(current_car, db)

@app.put("/cars/complete")
def complete_ride(current_car: models.Car = Depends(auth.get_current_car), db: Session = Depends(get_db)):
    return CarService.complete_ride(current_car, db)

@app.put("/cars/location")
def update_location(lat: float, lng: float, current_car: models.Car = Depends(auth.get_current_car), db: Session = Depends(get_db)):
    return CarService.update_location(current_car, lat, lng, db)


@app.post("/rides/{ride_id}/verify", response_model=schemas.RideResponse)
def verify_ride(
    ride_id: int,
    code: str,
    current_gucian: models.Gucian = Depends(auth.get_current_gucian),
    db: Session = Depends(get_db),
):
    return VerificationService.verify_code(ride_id, code, current_gucian, db)