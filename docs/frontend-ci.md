# Frontend Continuous Integration (CI) Workflow

This document describes the frontend CI workflow that automatically validates frontend code changes in pull requests.

## Overview

The frontend CI workflow (`ci-pr-frontend.yml`) automatically runs when changes are made to files in the `frontend/` directory. It follows the same pattern as the backend CI workflow and includes comprehensive validation steps.

**Note**: This frontend uses a **static-first approach** where NPM packages are only used for development tooling (testing, linting, formatting). The production Docker container contains only static HTML/CSS/JavaScript files served by Nginx, with no Node.js runtime or NPM dependencies. This provides excellent security, performance, and simplicity.

## What Gets Validated

### 1. **Code Quality & Static Analysis**
- **ESLint**: JavaScript linting to catch errors and enforce code standards
- **Prettier**: Code formatting to ensure consistent style
- **HTML Validation**: Validates HTML files for syntax errors
- **JavaScript Syntax Check**: Validates all JS files compile correctly
- **Static Asset Validation**: Ensures all referenced assets exist

### 2. **Security**
- **SAST (Static Application Security Testing)**: CodeQL analysis for security vulnerabilities in your JavaScript code

### 3. **Testing**
- **Unit Tests**: Jest-based tests with coverage reporting
- **Coverage Threshold**: Enforces minimum 80% code coverage

### 4. **Build Validation**
- **Docker Build**: Tests that the frontend container builds and starts successfully
- **Container Security Scanning**: Scans the built container for vulnerabilities

## Triggered By

The workflow runs on pull requests to the `development` branch when files change in:
- `frontend/**/*.js` (JavaScript files)
- `frontend/**/*.html` (HTML files)  
- `frontend/**/*.css` (CSS files)
- `frontend/Dockerfile` (Container config)
- `frontend/nginx.conf` (Web server config)
- `frontend/static/**` (Static assets)

## Workflow Jobs

### 1. `check_changes`
Detects which types of files changed to determine which validation steps to run:
- `lint_required`: JS/HTML/CSS files changed
- `build_required`: Dockerfile, nginx.conf, or static files changed

### 2. `format_and_lint`
- Runs ESLint on changed JavaScript files
- Runs Prettier to check code formatting
- Validates HTML files for syntax errors
- Checks JavaScript syntax compilation
- Validates static assets exist
- Uses `reusable-frontend-lint.yml`

### 3. `static_analysis`
- Performs CodeQL static analysis for security issues in your JavaScript code
- Uses `reusable-sast-scan.yml` with language: 'javascript'

### 4. `frontend_tests`
- Runs Jest unit tests with coverage
- Enforces 80% coverage threshold
- Uploads coverage reports
- Uses `reusable-frontend-test.yml`

### 5. `build_and_scan`
- Tests Docker container build 
- Performs Dockerfile configuration scanning
- Scans the built container for vulnerabilities
- Uses `reusable-container-scan.yml`

### 6. `post-comment`
- Posts validation results to the PR
- Shows which checks passed/failed
- Provides helpful error resolution tips

## Configuration Files

The following configuration files are created/used:

### `frontend/.eslintrc.js`
ESLint configuration for JavaScript linting:
```javascript
module.exports = {
  env: {
    browser: true,
    es2021: true,
    jest: true,
    node: true
  },
  extends: ['standard'],
  // ... additional rules
}
```

### `frontend/.prettierrc.json`
Prettier configuration for code formatting:
```json
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2,
  "useTabs": false
}
```

### `frontend/package.json` Scripts
Updated with linting and formatting commands:
```json
{
  "scripts": {
    "lint": "eslint static/**/*.js tests/**/*.js",
    "lint:fix": "eslint --fix static/**/*.js tests/**/*.js",
    "format": "prettier --write static/**/*.js tests/**/*.js static/**/*.css static/**/*.html",
    "format:check": "prettier --check static/**/*.js tests/**/*.js static/**/*.css static/**/*.html"
  }
}
```

## Development Workflow

### Before Pushing Code

1. **Run tests locally**:
   ```bash
   cd frontend
   npm test
   npm run test:coverage
   ```

2. **Check linting**:
   ```bash
   npm run lint
   ```

3. **Fix formatting**:
   ```bash
   npm run format
   ```

4. **Check for security issues**:
   ```bash
   # Only for development tools - not needed for production deployment
   npm audit
   ```

### When PR Fails

The workflow will post a comment with specific guidance, but common fixes include:

1. **Linting issues**:
   ```bash
   cd frontend
   npm run lint:fix
   ```

2. **Formatting issues**:
   ```bash
   cd frontend
   npm run format
   ```

3. **Security vulnerabilities**: 
   ```bash
   cd frontend
   # Only affects development tools, not production deployment
   npm audit fix
   ```

4. **Test failures**:
   - Check test output in the workflow logs
   - Fix failing tests and ensure coverage meets threshold

5. **Build issues**:
   - Validate HTML syntax
   - Check for missing static assets
   - Ensure Dockerfile builds correctly

## Dependencies Added

The workflow adds these development dependencies to `package.json`:
- `eslint` and related plugins for linting
- `prettier` for code formatting  
- `html-validate` for HTML validation

## Benefits

✅ **Automated Quality Assurance**: Every PR is automatically validated
✅ **Security First**: Static analysis catches security issues in your JavaScript code early
✅ **Consistent Code Style**: Enforced formatting and linting standards
✅ **Test Coverage**: Ensures code is properly tested
✅ **Build Validation**: Catches build issues before deployment
✅ **Fast Feedback**: Developers get immediate feedback on their changes
✅ **Lightweight**: No dependency scanning needed since NPM packages aren't in production

## Integration with Backend

This frontend CI workflow complements the existing backend CI workflow, providing comprehensive validation for the entire application stack. Both workflows use similar patterns and reusable components for consistency.
