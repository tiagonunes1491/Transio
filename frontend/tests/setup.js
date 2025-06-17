// Test setup file for frontend tests
// This file is run before each test file

// Mock global objects that might not be available in test environment
global.console = {
  ...console,
  error: jest.fn(),
  warn: jest.fn(),
  log: jest.fn()
};

// Mock localStorage
const localStorageMock = {
  getItem: jest.fn(),
  setItem: jest.fn(),
  removeItem: jest.fn(),
  clear: jest.fn()
};
Object.defineProperty(window, 'localStorage', {
  value: localStorageMock
});
global.localStorage = localStorageMock;

// Mock window.location
delete window.location;
window.location = {
  hostname: 'localhost',
  protocol: 'http:',
  origin: 'http://localhost:3000',
  hash: '',
  href: 'http://localhost:3000'
};

// Mock fetch globally
global.fetch = jest.fn();

// Mock IntersectionObserver
global.IntersectionObserver = jest.fn().mockImplementation((callback) => ({
  observe: jest.fn(),
  disconnect: jest.fn(),
  unobserve: jest.fn()
}));

// Mock navigator.clipboard
Object.defineProperty(navigator, 'clipboard', {
  value: {
    writeText: jest.fn()
  },
  writable: true
});

// Mock document.execCommand
document.execCommand = jest.fn();

// Mock alert and prompt
global.alert = jest.fn();
global.prompt = jest.fn();

// Clean up after each test
afterEach(() => {
  jest.clearAllMocks();
  document.body.innerHTML = '';
  // Clear localStorage mocks
  localStorageMock.getItem.mockClear();
  localStorageMock.setItem.mockClear();
  localStorageMock.removeItem.mockClear();
  localStorageMock.clear.mockClear();
});
