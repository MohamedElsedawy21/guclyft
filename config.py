from dotenv import load_dotenv
import os

load_dotenv()  # reads .env and loads it into environment variables

SECRET_KEY = os.getenv("SECRET_KEY")