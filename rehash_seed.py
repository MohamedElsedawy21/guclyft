from database import SessionLocal
import models, auth

db = SessionLocal()

for admin in db.query(models.Admin).all():
    admin.password = auth.hash_password(admin.password)

for gucian in db.query(models.Gucian).all():
    gucian.password = auth.hash_password(gucian.password)

db.commit()
db.close()
print("Passwords hashed successfully.")