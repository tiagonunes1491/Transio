#!/bin/bash
# backend/run_coverage_example.sh
# Example script demonstrating different coverage measurement options

echo "SecureSharer Backend - Coverage Measurement Examples"
echo "==================================================="

# Generate a temporary encryption key for testing
export MASTER_ENCRYPTION_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

echo "1. Running core functionality tests with coverage:"
echo "---------------------------------------------------"
python -m pytest tests/test_encryption.py tests/test_storage.py tests/test_models.py tests/test_main.py -v --cov=app --cov-report=term-missing

echo ""
echo "2. Generating HTML coverage report:"
echo "-----------------------------------"
python -m pytest tests/test_encryption.py tests/test_models.py -q --cov=app --cov-report=html:htmlcov

echo ""
echo "3. Coverage with specific threshold (95%):"
echo "------------------------------------------"
python -m pytest tests/test_encryption.py -q --cov=app --cov-report=term --cov-fail-under=95

echo ""
echo "4. Coverage report without running tests (from existing .coverage file):"
echo "------------------------------------------------------------------------"
python -m coverage report

echo ""
echo "Examples completed!"
echo "• Terminal report: See coverage summary above"
echo "• HTML report: Open htmlcov/index.html in browser"
echo "• Coverage data: Stored in .coverage file"