#!/bin/bash
# backend/run_tests.sh
# Simple script to run all backend tests with proper environment setup

# Generate a temporary encryption key for testing
export MASTER_ENCRYPTION_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

# Run pytest with verbose output
python -m pytest tests/ -v

echo ""
echo "Test run completed. All tests should pass."
echo "Total test count: $(python -c "import subprocess; result = subprocess.run(['python', '-m', 'pytest', 'tests/', '--collect-only', '-q'], capture_output=True, text=True); print(len([line for line in result.stdout.split('\n') if '::' in line and 'test_' in line]))")"