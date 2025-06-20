# backend/app/models.py
from datetime import datetime, timezone
import base64
from typing import Optional, Dict, Any


class Secret:
    """
    Document model for storing secrets in Cosmos DB.
    Represents a secret with automatic TTL cleanup.
    """

    def __init__(self, link_id: str, encrypted_secret: bytes, created_at: Optional[datetime] = None):
        self.id = link_id  # Use link_id as the document id for direct access
        self.link_id = link_id
        self.encrypted_secret = encrypted_secret
        self.created_at = created_at or datetime.now(timezone.utc)

    def to_dict(self) -> Dict[str, Any]:
        """Convert the Secret object to a dictionary for Cosmos DB storage."""
        return {
            'id': self.id,
            'link_id': self.link_id,
            'encrypted_secret': base64.b64encode(self.encrypted_secret).decode('utf-8'),
            'created_at': self.created_at.isoformat(),
            # TTL is handled by the container configuration (24 hours default)
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Secret':
        """Create a Secret object from a Cosmos DB document."""
        encrypted_secret = base64.b64decode(data['encrypted_secret'].encode('utf-8'))
        created_at = datetime.fromisoformat(data['created_at'])
        return cls(
            link_id=data['link_id'],
            encrypted_secret=encrypted_secret,
            created_at=created_at
        )

    def __repr__(self):
        return f"<Secret {self.link_id}>"
