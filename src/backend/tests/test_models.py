# backend/tests/test_models.py
import pytest
import uuid
from datetime import datetime, timezone, timedelta

from backend.app.models import Secret
from backend.app import db


class TestSecretModel:
    """Test cases for the Secret model."""
    
    def test_secret_creation(self, app_context):
        """Test creating a Secret instance."""
        link_id = str(uuid.uuid4())
        encrypted_data = b"test_encrypted_data"
        
        secret = Secret(
            link_id=link_id,
            encrypted_secret=encrypted_data
        )
        
        assert secret.link_id == link_id
        assert secret.encrypted_secret == encrypted_data
        # created_at is set by SQLAlchemy default when saved to DB
        # For an unsaved instance, it might be None
        # Let's test this after adding to session
    
    def test_secret_default_created_at(self, app_context):
        """Test that created_at is automatically set with timezone-aware UTC when saved to DB."""
        secret = Secret(
            link_id=str(uuid.uuid4()),
            encrypted_secret=b"test_data"
        )
        
        # Add to session and flush to trigger defaults
        db.session.add(secret)
        db.session.flush()  # This triggers the default value
        
        # The created_at should now be set
        assert secret.created_at is not None
        # Should be timezone-aware
        assert secret.created_at.tzinfo is not None
        # Should be close to current time (within 1 second)
        now = datetime.now(timezone.utc)
        time_diff = abs((now - secret.created_at).total_seconds())
        assert time_diff < 1.0
    
    def test_secret_database_persistence(self, app_context):
        """Test saving and retrieving Secret from database."""
        link_id = str(uuid.uuid4())
        encrypted_data = b"test_encrypted_data_for_db"
        
        # Create and save secret
        secret = Secret(
            link_id=link_id,
            encrypted_secret=encrypted_data
        )
        db.session.add(secret)
        db.session.commit()
        
        # Retrieve from database
        retrieved_secret = Secret.query.filter_by(link_id=link_id).first()
        
        assert retrieved_secret is not None
        assert retrieved_secret.link_id == link_id
        assert retrieved_secret.encrypted_secret == encrypted_data
        assert retrieved_secret.id is not None
        assert isinstance(retrieved_secret.id, int)
    
    def test_secret_unique_link_id_constraint(self, app_context):
        """Test that link_id must be unique."""
        link_id = str(uuid.uuid4())
        
        # Create first secret
        secret1 = Secret(
            link_id=link_id,
            encrypted_secret=b"data1"
        )
        db.session.add(secret1)
        db.session.commit()
        
        # Try to create second secret with same link_id
        secret2 = Secret(
            link_id=link_id,
            encrypted_secret=b"data2"
        )
        db.session.add(secret2)
        
        # Should raise integrity error due to unique constraint
        with pytest.raises(Exception):  # SQLAlchemy will raise an IntegrityError
            db.session.commit()
    
    def test_secret_repr(self, app_context):
        """Test the string representation of Secret model."""
        link_id = str(uuid.uuid4())
        secret = Secret(
            link_id=link_id,
            encrypted_secret=b"test_data"
        )
        
        repr_str = repr(secret)
        assert f"<Secret {link_id}>" == repr_str
    
    def test_secret_nullable_constraints(self, app_context):
        """Test that required fields cannot be null."""
        # Test missing link_id
        with pytest.raises(Exception):
            secret = Secret(encrypted_secret=b"test_data")
            db.session.add(secret)
            db.session.commit()
        
        db.session.rollback()
        
        # Test missing encrypted_secret
        with pytest.raises(Exception):
            secret = Secret(link_id=str(uuid.uuid4()))
            db.session.add(secret)
            db.session.commit()
    
    def test_secret_binary_data_storage(self, app_context):
        """Test that binary data is properly stored and retrieved."""
        # Test various binary data
        test_data = [
            b"simple text",
            b"\x00\x01\x02\x03\x04",  # Binary data with null bytes
            b"unicode: \xc3\xa9\xc3\xa1\xc3\xad",  # UTF-8 encoded unicode
            b"long data: " + b"x" * 10000,  # Large binary data
        ]
        
        for data in test_data:
            link_id = str(uuid.uuid4())
            secret = Secret(
                link_id=link_id,
                encrypted_secret=data
            )
            db.session.add(secret)
            db.session.commit()
            
            # Retrieve and verify
            retrieved = Secret.query.filter_by(link_id=link_id).first()
            assert retrieved.encrypted_secret == data
    
    def test_secret_query_by_created_at(self, app_context):
        """Test querying secrets by creation time."""
        # Create secrets at different times
        past_time = datetime.now(timezone.utc) - timedelta(hours=1)
        current_time = datetime.now(timezone.utc)
        
        old_secret = Secret(
            link_id=str(uuid.uuid4()),
            encrypted_secret=b"old_data",
            created_at=past_time
        )
        new_secret = Secret(
            link_id=str(uuid.uuid4()),
            encrypted_secret=b"new_data"
            # created_at will be set automatically to current time
        )
        
        db.session.add(old_secret)
        db.session.add(new_secret)
        db.session.commit()
        
        # Query for secrets created in the last 30 minutes
        cutoff_time = current_time - timedelta(minutes=30)
        recent_secrets = Secret.query.filter(Secret.created_at > cutoff_time).all()
        
        # Only the new secret should be returned
        assert len(recent_secrets) == 1
        assert recent_secrets[0].link_id == new_secret.link_id
    
    def test_secret_table_name(self, app_context):
        """Test that the table name is correctly set."""
        # This test verifies the __tablename__ attribute
        assert Secret.__tablename__ == 'secrets'
    
    def test_secret_multiple_instances(self, app_context):
        """Test creating and managing multiple Secret instances."""
        secrets_data = []
        
        # Create multiple secrets
        for i in range(5):
            link_id = str(uuid.uuid4())
            data = f"secret_data_{i}".encode()
            
            secret = Secret(
                link_id=link_id,
                encrypted_secret=data
            )
            secrets_data.append((link_id, data))
            db.session.add(secret)
        
        db.session.commit()
        
        # Verify all were saved
        assert Secret.query.count() == 5
        
        # Verify each secret individually
        for link_id, expected_data in secrets_data:
            secret = Secret.query.filter_by(link_id=link_id).first()
            assert secret is not None
            assert secret.encrypted_secret == expected_data