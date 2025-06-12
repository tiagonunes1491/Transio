# Coverage Measurement Guide

This guide explains how to use pytest-cov for comprehensive test coverage measurement in the SecureSharer backend.

## Overview

The backend now includes comprehensive coverage measurement using `pytest-cov`, which provides detailed insights into which parts of the codebase are being tested and which areas may need additional test coverage.

## Setup

### Dependencies
- `pytest-cov==6.0.0` - Coverage measurement plugin for pytest
- `coverage>=7.5` - Core coverage library (automatically installed with pytest-cov)

### Configuration
The coverage configuration is defined in `pytest.ini`:

```ini
[tool:pytest]
addopts = 
    --cov=app
    --cov-report=term-missing
    --cov-report=html:htmlcov
    --cov-fail-under=90

[coverage:run]
source = app
omit = 
    */tests/*
    */test_*
    */__pycache__/*

[coverage:report]
precision = 2
show_missing = true
skip_covered = false
```

## Usage

### Running Tests with Coverage

#### Full Test Suite with Coverage
```bash
cd backend
./run_tests.sh
```

#### Specific Test Module with Coverage
```bash
cd backend
export MASTER_ENCRYPTION_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
python -m pytest tests/test_encryption.py -v --cov=app --cov-report=term-missing
```

#### Coverage Only (without running tests again)
```bash
cd backend
python -m coverage report
python -m coverage html
```

### Coverage Reports

#### Terminal Report
Shows coverage summary directly in the terminal with missing line numbers:

```
Name                Stmts   Miss  Cover   Missing
-------------------------------------------------
app/__init__.py         4      0   100%
app/encryption.py      46      2    96%   23, 67
app/main.py            72      1    99%   45
app/models.py          10      0   100%
app/storage.py         71      3    96%   89, 112, 134
-------------------------------------------------
TOTAL                 203      6    97%
```

#### HTML Report
Detailed interactive HTML report generated in `htmlcov/index.html`:
- Line-by-line coverage visualization
- Highlighted uncovered lines
- Detailed coverage statistics per file
- Sortable and filterable views

### Coverage Thresholds

The configuration sets a minimum coverage threshold of **90%**. Tests will fail if coverage falls below this threshold, ensuring high code quality standards.

## Coverage Metrics

### Current Coverage Areas

The coverage measurement focuses on the core application modules:

- **`app/main.py`** - Flask API endpoints and route handlers
- **`app/encryption.py`** - Cryptographic functions for secret encryption/decryption
- **`app/storage.py`** - Database operations and data persistence
- **`app/models.py`** - SQLAlchemy database models
- **`app/__init__.py`** - Application initialization and database setup

### Excluded from Coverage

- Test files (`tests/`)
- Cache directories (`__pycache__/`)
- Virtual environment files
- Configuration files

## Best Practices

### Improving Coverage

1. **Identify Missing Coverage**
   ```bash
   python -m coverage report --show-missing
   ```

2. **Focus on Critical Paths**
   - Error handling branches
   - Edge cases
   - Security-critical functions

3. **Add Targeted Tests**
   - Create specific tests for uncovered lines
   - Test error conditions and exceptions
   - Validate input validation paths

### Coverage Quality

- **Aim for 90%+ coverage** but prioritize meaningful tests over coverage percentage
- **Test critical functionality thoroughly** (encryption, authentication, data handling)
- **Include edge cases and error scenarios** in test coverage
- **Regular coverage monitoring** during development

## CI/CD Integration

The coverage setup is ready for CI/CD integration:

```bash
# In CI pipeline
cd backend
export MASTER_ENCRYPTION_KEY=${{ secrets.ENCRYPTION_KEY }}
python -m pytest tests/ --cov=app --cov-report=xml --cov-fail-under=90
```

This will:
- Run all tests with coverage measurement
- Generate XML coverage report for CI tools
- Fail the build if coverage is below 90%

## Troubleshooting

### Common Issues

1. **Import Errors**
   - Ensure all dependencies are installed: `pip install -r requirements.txt`
   - Check PYTHONPATH includes the backend directory

2. **Missing Coverage Data**
   - Verify `MASTER_ENCRYPTION_KEY` environment variable is set
   - Check that test imports match source code structure

3. **Low Coverage Warnings**
   - Review `.coveragerc` exclusions
   - Ensure tests are actually exercising the code paths
   - Add tests for uncovered branches

### Debug Coverage

```bash
# Show detailed coverage information
python -m coverage debug sys

# Show coverage data file contents
python -m coverage debug data
```

## Security Considerations

- Coverage reports may reveal application structure - exclude from public repositories
- HTML reports are in `.gitignore` to prevent accidental commits
- Coverage data files (`.coverage`) are also excluded from version control