module.exports = {
  env: {
    browser: true,
    es2021: true,
    jest: true,
    node: true
  },
  extends: [
    'standard'
  ],
  parserOptions: {
    ecmaVersion: 12,
    sourceType: 'module'
  },
  rules: {
    // Add any custom rules here
    'no-console': 'warn',
    'no-debugger': 'error',
    'no-unused-vars': 'error',
    'prefer-const': 'error'
  },
  globals: {
    // Add any global variables used in your frontend
    'crypto': 'readonly',
    'TextEncoder': 'readonly',
    'TextDecoder': 'readonly'
  }
}
