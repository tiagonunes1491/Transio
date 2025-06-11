# Backend Unit Tests

This directory contains comprehensive unit tests for the SecureSharer backend application.

## Test Structure

- `test_encryption.py`: Tests for encryption and decryption functions (14 tests)
- `test_storage.py`: Tests for database storage operations (19 tests)  
- `test_models.py`: Tests for SQLAlchemy models (10 tests)
- `test_main.py`: Tests for Flask API endpoints (20 tests)
- `conftest.py`: Pytest configuration and fixtures

## Running Tests

### Prerequisites

1. Install test dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Set up environment variables:
   ```bash
   export MASTER_ENCRYPTION_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
   ```

### Run All Tests

```bash
# Using the provided script
./run_tests.sh

# Or manually
MASTER_ENCRYPTION_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())") python -m pytest tests/ -v
```

### Run Specific Test Files

```bash
# Test encryption functions only
MASTER_ENCRYPTION_KEY=<key> python -m pytest tests/test_encryption.py -v

# Test storage functions only  
MASTER_ENCRYPTION_KEY=<key> python -m pytest tests/test_storage.py -v

# Test models only
MASTER_ENCRYPTION_KEY=<key> python -m pytest tests/test_models.py -v

# Test API endpoints only
MASTER_ENCRYPTION_KEY=<key> python -m pytest tests/test_main.py -v
```

### Run Specific Test Cases

```bash
# Test a specific test class
MASTER_ENCRYPTION_KEY=<key> python -m pytest tests/test_encryption.py::TestEncryptSecret -v

# Test a specific test method
MASTER_ENCRYPTION_KEY=<key> python -m pytest tests/test_encryption.py::TestEncryptSecret::test_encrypt_secret_success -v
```

## Test Coverage

The test suite provides comprehensive coverage of:

### Encryption Module (`test_encryption.py`)
- ✅ Valid secret encryption/decryption
- ✅ Input validation (empty strings, wrong types)
- ✅ Unicode content handling
- ✅ Error handling for invalid tokens
- ✅ Cipher suite initialization issues
- ✅ Encryption/decryption roundtrip testing

### Storage Module (`test_storage.py`)
- ✅ Secret storage and retrieval operations
- ✅ One-time access functionality (auto-deletion)
- ✅ Link ID generation and uniqueness
- ✅ Expired secret cleanup
- ✅ Database error handling
- ✅ Input validation
- ✅ Integration testing

### Models Module (`test_models.py`)
- ✅ Secret model creation and persistence
- ✅ Database constraints (unique, nullable)
- ✅ Timezone-aware timestamp handling
- ✅ Binary data storage
- ✅ Query operations
- ✅ Model representation

### API Endpoints (`test_main.py`)
- ✅ Health check endpoint
- ✅ Secret sharing API with validation
- ✅ Secret retrieval API (GET and HEAD)
- ✅ Error handling and HTTP status codes
- ✅ JSON request/response format
- ✅ Unicode content support
- ✅ One-time access enforcement
- ✅ Complete workflow integration

## Test Configuration

- Uses SQLite in-memory database for isolated testing
- Generates temporary encryption keys for each test run
- Configures Flask in testing mode
- Provides fixtures for common test data
- Includes mock support for error simulation

## Expected Results

All 63 tests should pass:
- 14 encryption tests
- 19 storage tests
- 10 model tests
- 20 API endpoint tests

## Notes

- Tests use isolated database sessions to prevent interference
- Environment variables are set up automatically in conftest.py
- All tests can run independently or as a complete suite
- No modifications to application code were needed for testing