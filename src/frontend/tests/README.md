# Frontend Testing for Transio

This directory contains unit tests for the Transio frontend JavaScript code.

## Overview

The frontend testing suite validates the core JavaScript functionality of the Transio application, ensuring that all client-side features work correctly and securely.

## Test Coverage

The test suite covers three main JavaScript files:

### 1. `utils.test.js` - Utility Functions (19 tests)
- **HTML Security**: `escapeHTML()` function to prevent XSS attacks
- **URL Handling**: `truncateLink()` for safe URL display
- **Date Formatting**: `formatDate()` for user-friendly timestamps
- **Clipboard Operations**: `copyToClipboardFallback()` and `showCopySuccess()`

### 2. `index.test.js` - Main Page Functionality (25 tests)
- **Environment Detection**: Development vs production API endpoint selection
- **LocalStorage Management**: Link history storage and retrieval
- **API Interaction**: Secret creation and error handling
- **Input Validation**: Empty and whitespace-only input rejection
- **UI State Management**: Dynamic interface updates

### 3. `view.test.js` - Secret View Page Functionality (19 tests)
- **Link ID Extraction**: URL hash parsing and validation
- **Environment Detection**: Proper API endpoint configuration
- **UI State Management**: Loading, success, and error states
- **API Interaction**: Secret existence checking and retrieval
- **Modal Functionality**: Help modal show/hide behavior
- **Error Handling**: Invalid links and server errors
- **Security Considerations**: XSS prevention and input sanitization

## Running Tests

### Prerequisites
- Node.js 20+ 
- npm

### Installation
```bash
cd frontend
npm install
```

### Run Tests

#### Using the Test Script (Recommended)
```bash
# Run all tests
./scripts/run_tests.sh

# Run only unit tests (core functionality)
./scripts/run_tests.sh unit

# Run only security tests (penetration testing)
./scripts/run_tests.sh security

# Show help
./scripts/run_tests.sh help
```

#### Using npm directly
```bash
# Run all tests
npm test

# Run tests in watch mode (re-runs on file changes)
npm run test:watch

# Run specific test category
npm test -- --testPathPattern=tests/unit/      # Unit tests only
npm test -- --testPathPattern=tests/security/  # Security tests only

# Run specific test file
npm test -- --testPathPattern=utils.test.js
```

### Test Output
```
Test Suites: 4 passed, 4 total
Tests:       101 passed, 101 total
Snapshots:   0 total
Time:        3.273 s
```

## Test Structure

### Test Organization

The frontend tests are organized into logical subdirectories for better maintainability:

```
tests/
├── unit/                    # Core functionality tests
│   ├── index.test.js       # Main page functionality (25 tests)
│   ├── utils.test.js       # Utility functions (19 tests)
│   └── view.test.js        # Secret view page (19 tests)
├── security/               # Security-related tests
│   └── advanced-pentest.test.js  # Advanced penetration testing (38 tests)
├── setup.js                # Test environment configuration and mocks
├── utils-module.js         # Utility modules for testing
└── utils-testable.js       # Testable utility functions
```

### Test Categories

#### Unit Tests (`tests/unit/`)
Core functionality tests that validate the main application features:
- **Main Page Tests** (`index.test.js`) - API interaction, LocalStorage, UI state management
- **Utility Tests** (`utils.test.js`) - HTML escaping, URL handling, date formatting, clipboard operations
- **View Page Tests** (`view.test.js`) - Link parsing, secret retrieval, modal functionality

#### Security Tests (`tests/security/`)
Advanced security testing that validates application security:
- **Penetration Tests** (`advanced-pentest.test.js`) - OWASP compliance, input validation, XSS prevention

### Test Environment
- **Framework**: Jest with jsdom
- **Environment**: Browser-like environment with DOM simulation
- **Mocking**: localStorage, fetch API, DOM elements, and browser APIs

### Mock Objects
- **DOM Elements**: All expected HTML elements with proper event handlers
- **Browser APIs**: localStorage, fetch, navigator.clipboard, IntersectionObserver
- **Window Object**: location properties for environment testing

### Security Testing
The tests specifically validate security features:
- HTML escaping to prevent XSS attacks
- Safe URL handling and display
- Input validation and sanitization
- Proper API endpoint selection based on environment

## Files

- `package.json` - Test dependencies and scripts
- `scripts/run_tests.sh` - Test execution script with category support
- `tests/setup.js` - Test environment configuration and mocks
- `tests/unit/` - Core functionality tests
  - `tests/unit/index.test.js` - Main page functionality tests
  - `tests/unit/utils.test.js` - Utility function tests
  - `tests/unit/view.test.js` - Secret view page tests
- `tests/security/` - Security-related tests  
  - `tests/security/advanced-pentest.test.js` - Advanced penetration tests
- `tests/utils-module.js` - Utility modules for testing
- `tests/utils-testable.js` - Testable utility functions

## Integration with Backend Testing

While the backend has comprehensive security testing (133 tests covering OWASP Top 10), the frontend tests focus on:
- Client-side security (XSS prevention, input validation)
- User interface behavior and state management
- API integration and error handling
- Browser compatibility and feature detection

## Development Guidelines

When adding new frontend functionality:
1. Write tests first (TDD approach)
2. Ensure security considerations are tested
3. Mock external dependencies appropriately
4. Test both success and error scenarios
5. Validate UI state changes

## Security Notice

These tests validate frontend security without requiring actual backend services. All tests run in isolation and do not affect production data or make real API calls.