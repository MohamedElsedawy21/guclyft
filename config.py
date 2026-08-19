import os
from dotenv import load_dotenv
from fastapi_mail import ConnectionConfig

load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY")

mail_config = ConnectionConfig(
    MAIL_USERNAME=os.getenv("MAIL_USERNAME"),
    MAIL_PASSWORD=os.getenv("MAIL_PASSWORD"),
    MAIL_FROM=os.getenv("MAIL_FROM"),
    MAIL_PORT=int(os.getenv("MAIL_PORT")),
    MAIL_SERVER=os.getenv("MAIL_SERVER"),
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True,
)

print("DEBUG MAIL_USERNAME:", os.getenv("MAIL_USERNAME"))
print("DEBUG MAIL_PASSWORD:", os.getenv("MAIL_PASSWORD"))