from database import SessionLocal
import models, auth

db = SessionLocal()
for car in db.query(models.Car).all():
    car.password = auth.hash_password(car.password)
db.commit()
db.close()
print("Car passwords hashed.")