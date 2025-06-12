# E2E Tests Directory

This directory contains End-to-End (E2E) tests for the SecureSharer frontend application using Playwright.

## Test Coverage

The E2E tests validate complete user workflows and functionality:

### 🔄 User Workflows
- **Secret Creation Flow**: Complete journey from entering text to generating shareable links
- **Secret Viewing Flow**: Full process of accessing and revealing secrets via links  
- **Navigation Flow**: Moving between pages and UI interactions

### 🎯 Functional Areas
- Form interactions and validation
- API communication and responses
- Browser functionality (copy to clipboard, etc.)
- Responsive design across devices
- Error handling and edge cases

### 🌐 Cross-Browser Testing
- Chromium (Chrome, Edge)
- Firefox
- WebKit (Safari)
- Mobile browsers (Chrome, Safari)

## Test Structure

```
e2e/
├── secret-creation.spec.js    # Testing secret creation workflow
├── secret-viewing.spec.js     # Testing secret viewing workflow
├── navigation.spec.js         # Testing page navigation and UI
├── error-handling.spec.js     # Testing error scenarios
└── helpers/                   # Shared test utilities
    └── test-helpers.js
```

## Running Tests

```bash
# Install dependencies
npm install

# Install Playwright browsers (first time only)
npm run playwright:install

# Run all E2E tests
npm run test:e2e

# Run tests with browser UI (headed mode)
npm run test:e2e:headed

# Debug tests interactively
npm run test:e2e:debug

# Run both unit and E2E tests
npm run test:all
```

## Test Statistics

- **Total E2E Tests**: 78 comprehensive tests
- **Test Suites**: 4 specialized test files
- **Browser Coverage**: Chrome, Firefox, Safari, Mobile Chrome, Mobile Safari
- **Test Categories**: User workflows, error handling, navigation, security

## Key Features Tested

### Secret Creation
- Text input validation
- Secret encryption and submission
- Link generation and display
- Copy to clipboard functionality
- Form reset after creation
- Local storage history tracking

### Secret Viewing  
- URL hash parsing for secret IDs
- Secret existence verification
- One-time reveal mechanism
- Secret deletion after viewing
- Error handling for invalid/expired links
- Help modal functionality

### User Experience
- Responsive design on different screen sizes
- Keyboard navigation and accessibility
- Loading states and feedback
- Error messages and recovery
- Navigation between pages

## Test Environment

- **Local Server**: Tests run against a local HTTP server serving static files
- **Mock Backend**: Uses mock API responses for consistent testing
- **Browser Automation**: Full browser instances for realistic user simulation
- **Cross-Platform**: Tests run on multiple operating systems and browsers

## Best Practices

- Tests are isolated and can run in parallel
- Each test starts with a clean state
- Real browser interactions (no shortcuts)
- Comprehensive assertions for user-visible behavior
- Screenshots and videos captured on failure
- Trace recording for debugging

## Continuous Integration

E2E tests are designed to run in CI environments with:
- Headless browser execution
- Retry logic for flaky tests
- Detailed reporting and artifacts
- Parallel execution for speed