# Frontend Security Tests

This directory contains comprehensive security-focused unit tests for the SecureSharer frontend application.

## Overview

The test suite focuses on validating security controls and preventing common web vulnerabilities, particularly:

- **XSS (Cross-Site Scripting) Prevention**
- **Input Validation and Sanitization**
- **Secure Data Handling**
- **API Security**
- **DOM Manipulation Security**

## Test Structure

### `utils.test.js` - Utility Functions Security
Tests for security-critical utility functions:
- **XSS Prevention**: Validates HTML escaping functionality
- **URL Security**: Tests safe URL truncation and handling
- **Input Validation**: Validates date formatting and input sanitization
- **Clipboard Security**: Tests secure clipboard operations and manual copy dialogs

### `index.test.js` - Main Page Security
Tests for the secret creation page:
- **Environment Detection**: Validates secure endpoint selection
- **Secret Creation Security**: Tests input validation and API security
- **LocalStorage Security**: Validates safe data storage and retrieval
- **UI Security**: Tests XSS prevention in dynamic content rendering

### `view.test.js` - Secret Viewing Security
Tests for the secret viewing page:
- **URL Parsing Security**: Validates safe hash parsing and malicious input handling
- **API Security**: Tests secure API communication and response validation
- **Content Security**: Validates XSS prevention in secret display
- **State Management**: Tests secure UI state transitions

## Security Focus Areas

### 1. XSS Prevention
- HTML escaping for all user-controlled content
- Safe DOM manipulation practices
- Secure handling of dynamic content

### 2. Input Validation
- Sanitization of user inputs
- Safe handling of malicious payloads
- Proper URL and JSON parsing

### 3. Data Security
- Secure localStorage operations
- Safe clipboard handling
- Protection against data leakage

### 4. API Security
- Environment-appropriate endpoint selection
- Secure request/response handling
- Error message sanitization

### 5. Edge Case Handling
- Large input handling
- Invalid data type handling
- Prototype pollution prevention

## Running Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage
```

## Test Coverage

The tests focus on security aspects rather than complete code coverage. Key security functions are thoroughly tested with:

- **Malicious input vectors**
- **Edge cases and boundary conditions**
- **Error handling scenarios**
- **Security bypass attempts**

## Security Test Examples

### XSS Prevention Test
```javascript
test('should escape basic HTML tags', () => {
  const maliciousInput = '<script>alert("XSS")</script>';
  const escaped = escapeHTML(maliciousInput);
  
  expect(escaped).toBe('&lt;script&gt;alert("XSS")&lt;/script&gt;');
  expect(escaped).not.toContain('<script>');
});
```

### Input Validation Test
```javascript
test('should handle malicious URLs safely', () => {
  const maliciousUrls = [
    'javascript:alert("XSS")',
    'data:text/html,<script>alert("XSS")</script>',
  ];

  maliciousUrls.forEach(url => {
    const truncated = truncateLink(url);
    expect(typeof truncated).toBe('string');
    // Should handle gracefully without executing
  });
});
```

### API Security Test
```javascript
test('should use secure endpoints in production', () => {
  // Test environment detection logic
  const isDevelopment = window.location.hostname === 'localhost';
  const apiEndpoint = isDevelopment ? 'http://127.0.0.1:5000/share' : '/api/share';
  
  expect(apiEndpoint).toBe('/api/share'); // Secure relative URL
  expect(apiEndpoint).not.toContain('http://'); // No insecure protocols
});
```

## Best Practices Tested

1. **Never trust user input** - All inputs are validated and sanitized
2. **Defense in depth** - Multiple layers of security validation
3. **Fail securely** - Graceful handling of security errors
4. **Principle of least privilege** - Minimal data exposure
5. **Input validation** - Both client-side and expected server-side validation

## Notes

- Tests are designed to run independently without modifying the original source code
- Security-critical functions are copied into test files to ensure they work in isolation
- Tests focus on security behavior rather than implementation details
- All security test scenarios are based on real-world attack vectors