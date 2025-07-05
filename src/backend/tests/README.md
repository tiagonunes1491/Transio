# Backend Tests

This directory contains the test suite for Transio backend. 

## Quick Start

```bash
# Set up environment
export MASTER_ENCRYPTION_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

# Run all tests with coverage
../scripts/run_tests.sh

# Run specific test categories
python -m pytest tests/unit/ -v           # Unit tests only
python -m pytest tests/security/ -v       # Security tests only
python -m pytest tests/unit/test_encryption.py -v  # Specific test file
```

## Test Organization

Tests are organized into logical subdirectories:

### Unit Tests (`tests/unit/`)
Core functionality tests for individual components:
- `test_encryption.py` - Cryptographic functions
- `test_storage.py` - Database operations  
- `test_models.py` - Data models
- `test_main.py` - API endpoints
- `test_main_module.py` - Main module functionality
- `test_multifernet.py` - Multi-key encryption

### Security Tests (`tests/security/`)
Comprehensive security validation tests:
- `test_security.py` - Basic security tests
- `test_penetration.py` - Penetration testing
- `test_advanced_pentest.py` - Advanced penetration tests
- `test_protocol_pentest.py` - Protocol-level security
- `test_comprehensive_owasp.py` - OWASP compliance
- `test_complete_security_coverage.py` - Final security validation

### Configuration
- `conftest.py` (fixtures), `pytest.ini` (settings)

## Coverage

Current coverage: **92%** (exceeds 90% threshold)
- Total: 222 tests 
- Results: 220 passed, 1 skipped, 1 failed

## Developer Notes

- All tests use isolated in-memory SQLite databases
- Environment variables are configured automatically via `conftest.py`
- Security tests simulate attacks without compromising system integrity
- See `COVERAGE_GUIDE.md` for detailed coverage measurement instructions

For comprehensive documentation see: **[docs/backend-testing.md](../../docs/backend-testing.md)**