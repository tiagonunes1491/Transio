/**
 * Jest setup file for frontend tests
 * Sets up JSDOM environment and global test utilities
 */

// Add TextEncoder/TextDecoder for JSDOM compatibility
const { TextEncoder, TextDecoder } = require('util');
global.TextEncoder = TextEncoder;
global.TextDecoder = TextDecoder;

// Mock console methods for cleaner test output
global.console = {
  ...console,
  // Uncomment to suppress console.log in tests
  // log: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
};

// Mock fetch globally for all tests
global.fetch = jest.fn();

// Mock localStorage
const localStorageMock = {
  getItem: jest.fn(),
  setItem: jest.fn(),
  removeItem: jest.fn(),
  clear: jest.fn(),
};
global.localStorage = localStorageMock;

// Mock IntersectionObserver for floating button tests
global.IntersectionObserver = jest.fn(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}));

// Clean up after each test
afterEach(() => {
  // Clear all mocks
  jest.clearAllMocks();
  
  // Clear localStorage mock
  localStorageMock.getItem.mockClear();
  localStorageMock.setItem.mockClear();
  localStorageMock.removeItem.mockClear();
  localStorageMock.clear.mockClear();
  
  // Clear DOM
  document.body.innerHTML = '';
  document.head.innerHTML = '';
  
  // Reset window.location
  delete window.location;
  window.location = {
    origin: 'http://localhost:3000',
    hostname: 'localhost',
    protocol: 'http:',
    hash: '',
  };
});