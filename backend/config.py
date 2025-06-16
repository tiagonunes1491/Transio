# backend/config.py
import os
import logging
from dotenv import load_dotenv
from cryptography.fernet import Fernet

# Configure basic logging
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

# Load environment variables from .env file in the current directory (backend/)
# This should be called as early as possible,
# and before importing any module that depends on environment variables
dotenv_path = os.path.join(os.path.dirname(__file__), ".env")
if os.path.exists(dotenv_path):
    load_dotenv(dotenv_path)
else:
    # This is a fallback for environments where .env might not be present
    # (e.g., production if variables are set directly)
    # but for local dev, .env is expected.
    logging.warning(
        f".env file not found at {dotenv_path}. "
        "Ensure MASTER_ENCRYPTION_KEY is set via environment variables if .env is not used."
    )


class Config:
    MASTER_ENCRYPTION_KEY = os.getenv("MASTER_ENCRYPTION_KEY")
    FLASK_APP = os.getenv("FLASK_APP", "app/main.py")  # Default value if not in .env
    FLASK_DEBUG = os.getenv("FLASK_DEBUG", "True").lower() in (
        "true",
        "1",
        "t",
    )  # Default to True, handle string 'True'
    # Add MAX_SECRET_LENGTH, defaulting to 100KB if not set in .env
    MAX_SECRET_LENGTH_KB = int(os.getenv("MAX_SECRET_LENGTH_KB", "100"))
    MAX_SECRET_LENGTH_BYTES = MAX_SECRET_LENGTH_KB * 1024

    # --- Database Configuration ---
    # 1) Prefer a fully-formed DATABASE_URL if provided (e.g. by docker-compose).
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL")

    if not SQLALCHEMY_DATABASE_URI:
        # 2) Otherwise build it from individual parts.
        DB_USER = os.getenv("DATABASE_USER")
        DB_PASSWORD = os.getenv("DATABASE_PASSWORD")
        DB_HOST = os.getenv("DATABASE_HOST")
        DB_PORT = os.getenv("DATABASE_PORT")
        DB_NAME = os.getenv("DATABASE_NAME")

        if all([DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME]):
            # Get SSL mode from environment variable, default to 'disable' for development
            # Set DATABASE_SSL_MODE=require for production Azure PostgreSQL
            ssl_mode = os.getenv("DATABASE_SSL_MODE", "disable")

            SQLALCHEMY_DATABASE_URI = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}?sslmode={ssl_mode}"
            logging.info(
                "Database URI constructed: "
                f"postgresql://{DB_USER}:<PASSWORD_HIDDEN>@{DB_HOST}:{DB_PORT}/{DB_NAME}?sslmode={ssl_mode}"
            )
        else:
            # 3) Log which pieces are missing (no unpacking bug).
            missing = [
                name
                for name, value in {
                    "DATABASE_USER": DB_USER,
                    "DATABASE_PASSWORD": DB_PASSWORD,
                    "DATABASE_HOST": DB_HOST,
                    "DATABASE_PORT": DB_PORT,
                    "DATABASE_NAME": DB_NAME,
                }.items()
                if not value
            ]
            logging.error(
                "CRITICAL: Database URI could not be constructed. "
                f"Missing environment variables: {', '.join(missing)}."
            )
            SQLALCHEMY_DATABASE_URI = None  # will make the app exit later

    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Defines time that secret expires in minutes
    # Default to 60 minutes if not set in .env
    SECRET_EXPIRY_MINUTES = int(os.getenv("SECRET_EXPIRY_MINUTES", "60"))

    if not MASTER_ENCRYPTION_KEY:
        # Fail fast - encryption key is required for this security application
        raise ValueError(
            "MASTER_ENCRYPTION_KEY not set. Please set it in .env file or environment."
        )

    # Ensure the key is bytes for Fernet and validate it's a proper Fernet key
    try:
        MASTER_ENCRYPTION_KEY_BYTES = MASTER_ENCRYPTION_KEY.encode("utf-8")
        # Test if it's a valid Fernet key by attempting to initialize a Fernet instance
        Fernet(MASTER_ENCRYPTION_KEY_BYTES)  # This will raise if invalid
    except Exception as e:
        # Log the error and re-raise with a clearer message
        logging.error(f"Invalid MASTER_ENCRYPTION_KEY: {e}")
        raise ValueError(f"Invalid MASTER_ENCRYPTION_KEY: {e}")


# You can add other configuration variables here as needed
