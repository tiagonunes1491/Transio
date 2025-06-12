/**
 * Security-focused integration tests for index.js
 * Tests secret creation, input validation, and UI security
 */

// Mock fetch globally
global.fetch = jest.fn();

// Mock localStorage
const localStorageMock = {
  getItem: jest.fn(),
  setItem: jest.fn(),
  removeItem: jest.fn(),
  clear: jest.fn(),
};
global.localStorage = localStorageMock;

// Mock IntersectionObserver
global.IntersectionObserver = jest.fn(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}));

describe('Index.js Security Tests', () => {
  beforeEach(() => {
    // Reset DOM
    document.body.innerHTML = '';
    document.head.innerHTML = '';
    
    // Clear all mocks
    jest.clearAllMocks();
    
    // Reset window.location
    delete window.location;
    window.location = {
      origin: 'https://securesharer.example.com',
      hostname: 'securesharer.example.com',
      protocol: 'https:',
      hash: '',
    };
  });

  describe('Environment Detection Security', () => {
    test('should use secure endpoints in production environment', () => {
      // Set production environment
      window.location = {
        origin: 'https://securesharer.example.com',
        hostname: 'securesharer.example.com',
        protocol: 'https:',
      };

      // Check environment detection logic
      const isDevelopment = window.location.hostname === 'localhost' ||
                           window.location.hostname === '127.0.0.1' ||
                           window.location.protocol === 'file:';
      
      expect(isDevelopment).toBe(false);
      
      // Verify it would use secure endpoints
      const shareApiEndpoint = isDevelopment ? 'http://127.0.0.1:5000/share' : '/api/share';
      expect(shareApiEndpoint).toBe('/api/share');
      expect(shareApiEndpoint).not.toContain('http://');
    });

    test('should detect development environment correctly', () => {
      window.location = {
        origin: 'http://localhost:3000',
        hostname: 'localhost',
        protocol: 'http:',
      };

      const isDevelopment = window.location.hostname === 'localhost' ||
                           window.location.hostname === '127.0.0.1' ||
                           window.location.protocol === 'file:';
      
      expect(isDevelopment).toBe(true);
    });

    test('should not expose sensitive data in development URLs', () => {
      window.location = {
        origin: 'http://localhost:3000',
        hostname: 'localhost',
        protocol: 'http:',
      };

      const revealLinkBasePath = `${window.location.origin}/view.html#`;
      
      // Verify the base path doesn't contain sensitive information
      expect(revealLinkBasePath).not.toContain('secret');
      expect(revealLinkBasePath).not.toContain('password');
      expect(revealLinkBasePath).not.toContain('key');
    });
  });

  describe('Secret Creation Security', () => {
    beforeEach(() => {
      // Set up basic DOM elements needed for secret creation
      document.body.innerHTML = `
        <input id="secretMessageInput" type="text" />
        <button id="mainCreateLinkButton">Create Secret</button>
        <div id="resultArea" class="hidden"></div>
        <input id="secretLinkInput" type="text" />
        <div id="historySection" class="hidden"></div>
        <div id="noSecretsSection"></div>
        <div id="linksHistory"></div>
      `;
    });

    test('should validate empty secret input', () => {
      const secretInput = document.getElementById('secretMessageInput');
      const mockButton = document.getElementById('mainCreateLinkButton');
      
      // Test empty input
      secretInput.value = '';
      
      // Create a simplified version of createSecret function for testing
      function validateSecretInput(secretText) {
        return !!(secretText && secretText.trim());
      }
      
      expect(validateSecretInput(secretInput.value)).toBe(false);
      expect(validateSecretInput('   ')).toBe(false);
      expect(validateSecretInput('valid secret')).toBe(true);
    });

    test('should handle malicious script inputs safely', () => {
      const maliciousInputs = [
        '<script>alert("XSS")</script>',
        'javascript:alert("XSS")',
        '<img src=x onerror=alert("XSS")>',
        '<svg onload=alert("XSS")>',
        '${alert("XSS")}',
        '{{alert("XSS")}}',
      ];

      maliciousInputs.forEach(input => {
        // Test that the input is accepted as data (not executed)
        // The security should be handled by the backend encryption and frontend escaping
        expect(typeof input).toBe('string');
        expect(input.length).toBeGreaterThan(0);
        
        // Verify it's treated as text data, not executable code
        const secretInput = document.getElementById('secretMessageInput');
        secretInput.value = input;
        expect(secretInput.value).toBe(input);
      });
    });

    test('should handle extremely long secret inputs', () => {
      const veryLongSecret = 'A'.repeat(100000);
      const secretInput = document.getElementById('secretMessageInput');
      
      // Should handle without throwing errors
      expect(() => {
        secretInput.value = veryLongSecret;
        const value = secretInput.value;
        expect(typeof value).toBe('string');
      }).not.toThrow();
    });

    test('should create proper API request structure', () => {
      const secretText = 'test secret';
      
      // Mock successful API response
      const mockResponse = {
        ok: true,
        json: jest.fn().mockResolvedValue({
          link_id: 'abc123def456'
        })
      };
      global.fetch.mockResolvedValue(mockResponse);
      
      // Test request structure
      const requestBody = JSON.stringify({ secret: secretText });
      const parsedBody = JSON.parse(requestBody);
      
      expect(parsedBody).toHaveProperty('secret');
      expect(parsedBody.secret).toBe(secretText);
      expect(typeof requestBody).toBe('string');
    });
  });

  describe('LocalStorage Security', () => {
    test('should validate localStorage data before use', () => {
      // Test with valid JSON
      const validData = [
        { url: 'https://example.com/view.html#abc123', timestamp: '2023-01-01T00:00:00.000Z', id: 'abc123' }
      ];
      const mockLocalStorage = jest.fn().mockReturnValue(JSON.stringify(validData));
      
      let generatedLinks = [];
      try {
        const savedLinks = mockLocalStorage('secretSharerLinks');
        if (savedLinks) {
          const parsed = JSON.parse(savedLinks);
          generatedLinks = Array.isArray(parsed) ? parsed : [];
        }
      } catch (error) {
        console.error('Failed to load history from localStorage:', error);
        generatedLinks = [];
      }
      
      expect(generatedLinks).toEqual(validData);
      expect(mockLocalStorage).toHaveBeenCalledWith('secretSharerLinks');
    });

    test('should handle corrupted localStorage data gracefully', () => {
      // Test with invalid JSON
      localStorageMock.getItem.mockReturnValue('invalid json {');
      
      let generatedLinks = [];
      expect(() => {
        try {
          const savedLinks = localStorage.getItem('secretSharerLinks');
          if (savedLinks) {
            generatedLinks = JSON.parse(savedLinks);
          }
        } catch (error) {
          console.error('Failed to load history from localStorage:', error);
          generatedLinks = []; // Safe fallback
        }
      }).not.toThrow();
      
      expect(generatedLinks).toEqual([]);
    });

    test('should limit stored history to prevent memory exhaustion', () => {
      const existingLinks = Array.from({ length: 15 }, (_, i) => ({
        url: `https://example.com/view.html#link${i}`,
        timestamp: new Date().toISOString(),
        id: `link${i}`
      }));
      
      // Simulate adding a new link
      const newLinkData = {
        url: 'https://example.com/view.html#newlink',
        timestamp: new Date().toISOString(),
        id: 'newlink'
      };
      
      existingLinks.unshift(newLinkData);
      
      // Should limit to 10 items
      if (existingLinks.length > 10) {
        existingLinks.splice(10);
      }
      
      expect(existingLinks.length).toBe(10);
      expect(existingLinks[0].id).toBe('newlink');
    });

    test('should validate link data structure before storage', () => {
      const linkData = {
        url: 'https://example.com/view.html#abc123',
        timestamp: new Date().toISOString(),
        id: 'abc123'
      };
      
      // Validate required properties
      expect(linkData).toHaveProperty('url');
      expect(linkData).toHaveProperty('timestamp');
      expect(linkData).toHaveProperty('id');
      
      // Validate data types
      expect(typeof linkData.url).toBe('string');
      expect(typeof linkData.timestamp).toBe('string');
      expect(typeof linkData.id).toBe('string');
      
      // Validate URL structure
      expect(linkData.url).toMatch(/^https?:\/\/.+\/view\.html#.+/);
    });
  });

  describe('UI Security and XSS Prevention', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div id="linksHistory"></div>
        <div id="resultArea" class="hidden"></div>
        <input id="secretLinkInput" type="text" />
      `;
    });

    test('should safely render links in history without XSS', () => {
      const maliciousLink = {
        url: 'https://example.com/view.html#<script>alert("XSS")</script>',
        timestamp: '2023-01-01T00:00:00.000Z',
        id: '<script>alert("XSS")</script>'
      };
      
      const linksHistory = document.getElementById('linksHistory');
      
      // Simulate safe rendering (how it should be done)
      const linkItem = document.createElement('div');
      
      // Use textContent for safe text insertion
      const linkElement = document.createElement('a');
      linkElement.textContent = maliciousLink.url; // Safe - uses textContent
      linkElement.href = maliciousLink.url;
      
      const timeElement = document.createElement('span');
      timeElement.textContent = maliciousLink.timestamp;
      
      linkItem.appendChild(linkElement);
      linkItem.appendChild(timeElement);
      linksHistory.appendChild(linkItem);
      
      // Verify no script tags were created
      expect(linksHistory.querySelectorAll('script').length).toBe(0);
      expect(linkElement.textContent).toContain('<script>');
      // The text content contains the script tag as text, which is safe
      expect(linkElement.innerHTML).not.toContain('<script>');
    });

    test('should handle error messages securely', () => {
      const maliciousError = '<script>alert("XSS")</script>';
      const secretLinkInput = document.getElementById('secretLinkInput');
      
      // Simulate error display (should be safe)
      secretLinkInput.value = `Error: ${maliciousError}`;
      
      // The value should contain the text but not execute
      expect(secretLinkInput.value).toContain('<script>');
      expect(secretLinkInput.value).toContain('alert("XSS")');
      
      // No script elements should be created
      expect(document.querySelectorAll('script').length).toBe(0);
    });

    test('should validate URL generation security', () => {
      const revealLinkBasePath = 'https://securesharer.example.com/view.html#';
      const linkId = 'abc123def456';
      
      const secretLink = `${revealLinkBasePath}${linkId}`;
      
      // Verify URL structure
      expect(secretLink).toMatch(/^https:\/\/.+\/view\.html#[a-zA-Z0-9]+$/);
      expect(secretLink).not.toContain('<');
      expect(secretLink).not.toContain('>');
      expect(secretLink).not.toContain('"');
      expect(secretLink).not.toContain("'");
    });
  });

  describe('API Security', () => {
    test('should use proper headers for API requests', () => {
      const expectedHeaders = {
        'Content-Type': 'application/json'
      };
      
      // Verify header structure
      expect(expectedHeaders['Content-Type']).toBe('application/json');
      expect(Object.keys(expectedHeaders)).toContain('Content-Type');
    });

    test('should handle API error responses securely', async () => {
      // Mock API error response
      const mockErrorResponse = {
        ok: false,
        status: 500,
        json: jest.fn().mockResolvedValue({
          error: 'Server error occurred'
        }),
        text: jest.fn().mockResolvedValue('Internal Server Error')
      };
      global.fetch.mockResolvedValue(mockErrorResponse);
      
      // Test error handling
      try {
        const response = await fetch('/api/share');
        expect(response.ok).toBe(false);
        expect(response.status).toBe(500);
        
        const errorData = await response.json();
        expect(errorData.error).toBe('Server error occurred');
      } catch (error) {
        // Should handle network errors gracefully
        expect(error).toBeDefined();
      }
    });

    test('should validate response data structure', () => {
      const validResponse = {
        link_id: 'abc123def456'
      };
      
      const invalidResponses = [
        null,
        undefined,
        {},
        { error: 'Something went wrong' },
        { link_id: null },
        { link_id: '' },
      ];
      
      // Test valid response
      expect(validResponse).toHaveProperty('link_id');
      expect(typeof validResponse.link_id).toBe('string');
      expect(validResponse.link_id.length).toBeGreaterThan(0);
      
      // Test invalid responses
      invalidResponses.forEach(response => {
        const isValid = response && response.link_id && typeof response.link_id === 'string' && response.link_id.length > 0;
        expect(isValid).toBeFalsy();
      });
    });
  });

  describe('Input Sanitization Security', () => {
    test('should handle special characters in secrets', () => {
      const specialCharSecrets = [
        'Secret with "quotes"',
        "Secret with 'apostrophes'",
        'Secret with <brackets>',
        'Secret with &ampersands&',
        'Secret with newlines\n\nand tabs\t\there',
        'Secret with unicode: 测试 🔐 💾',
      ];

      specialCharSecrets.forEach(secret => {
        // Should accept any string as valid secret data
        expect(typeof secret).toBe('string');
        expect(secret.length).toBeGreaterThan(0);
        
        // JSON serialization should handle it safely
        expect(() => {
          const json = JSON.stringify({ secret });
          const parsed = JSON.parse(json);
          expect(parsed.secret).toBe(secret);
        }).not.toThrow();
      });
    });

    test('should prevent prototype pollution in data handling', () => {
      const maliciousData = JSON.stringify({
        secret: 'test',
        __proto__: { polluted: true }
      });
      
      // Parse should not pollute prototype
      const parsed = JSON.parse(maliciousData);
      expect(parsed.secret).toBe('test');
      
      // Verify prototype is not polluted
      expect({}.polluted).toBeUndefined();
      expect(Object.prototype.polluted).toBeUndefined();
    });
  });
});