import os
from dotenv import load_dotenv

# Try sensible locations in order
ENV_PATHS = [
    os.path.join(os.path.dirname(__file__), "..", ".env"),             # backend/Team-Try/.env
    os.path.join(os.path.dirname(__file__), "..", "..", ".env"),       # backend/.env
    os.path.join(os.path.dirname(__file__), "..", "..", "..", ".env")  # repo root .env
]

LOADED_ENV_PATH = None
for env_path in ENV_PATHS:
    if os.path.exists(os.path.abspath(env_path)):
        load_dotenv(os.path.abspath(env_path))
        LOADED_ENV_PATH = os.path.abspath(env_path)
        break

SUPABASE_URL = os.getenv("SUPABASE_URL", "").strip()
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "").strip()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()

CLOUDINARY_CONFIG = {
    "cloud_name": os.getenv("CLOUD_NAME", "").strip(),
    "api_key": os.getenv("CLOUD_API_KEY", "").strip(),
    "api_secret": os.getenv("CLOUD_API_SECRET", "").strip()
}