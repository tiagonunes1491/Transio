# Backend Tests

This directory contains the test suite for SecureSharer backend. 

## Quick Start

```bash
# Set up environment
export MASTER_ENCRYPTION_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

# Run all tests with coverage
../run_tests.sh

# Run specific test modules
python -m pytest tests/test_encryption.py -v
python -m pytest tests/test_main_module.py -v
```

## Test Organization

- **Core Tests**: `test_encryption.py`, `test_storage.py`, `test_models.py`, `test_main.py`, `test_main_module.py`
- **Security Tests**: `test_security.py`, `test_penetration.py`, `test_advanced_pentest.py`, `test_protocol_pentest.py`, `test_comprehensive_owasp.py`, `test_complete_security_coverage.py`
- **Configuration**: `conftest.py` (fixtures), `pytest.ini` (settings)

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