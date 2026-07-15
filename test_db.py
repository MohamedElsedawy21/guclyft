from database import engine
from sqlalchemy import text

try:
    with engine.connect() as connection:
        result = connection.execute(text("SELECT 1"))
        print("✅ Database connected successfully:", result.scalar())
except Exception as e:
    print("❌ Connection failed:", e)