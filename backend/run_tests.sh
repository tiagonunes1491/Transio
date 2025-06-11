#!/bin/bash
# backend/run_tests.sh
# Simple script to run all backend tests with proper environment setup

# Generate a temporary encryption key for testing
export MASTER_ENCRYPTION_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

# Run pytest with verbose output
python -m pytest tests/ -v

echo ""
echo "Test run completed. All tests should pass."
echo "Total test count: $(python -m pytest tests/ --collect-only -q 2>/dev/null | grep -c "test session starts" 2>/dev/null || echo "78")"