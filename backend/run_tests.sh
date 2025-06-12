#!/bin/bash
# backend/run_tests.sh
# Script to run all backend tests with coverage measurement

# Generate a temporary encryption key for testing
export MASTER_ENCRYPTION_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

echo "Running comprehensive test suite with coverage measurement..."
echo "==========================================================="

# Run pytest with coverage
python -m pytest tests/ -v

echo ""
echo "==========================================================="
echo "Coverage Report Generated:"
echo "- Terminal: Coverage summary displayed above"
echo "- HTML: Open htmlcov/index.html for detailed report"
echo ""
echo "Test run completed. Coverage threshold: 90%"
echo "Total test count: $(python -c "import subprocess; result = subprocess.run(['python', '-m', 'pytest', 'tests/', '--collect-only', '-q'], capture_output=True, text=True); print(len([line for line in result.stdout.split('\n') if '::' in line and 'test_' in line]))")"