# backend/app/models.py
from datetime import datetime, timezone # Import timezone
from . import db # ADD THIS LINE - db is now from app/__init__.py

class Secret(db.Model):
    __tablename__ = 'secrets' # Optional: explicitly define table name

    id = db.Column(db.Integer, primary_key=True)
    link_id = db.Column(db.String(36), unique=True, nullable=False, index=True) # UUIDs are 36 chars
    encrypted_secret = db.Column(db.LargeBinary, nullable=False) # For storing bytes
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)) # Use timezone-aware UTC now

    def __repr__(self):
        return f'<Secret {self.link_id}>'