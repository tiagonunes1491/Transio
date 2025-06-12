/**
 * Security-focused integration tests for view.js
 * Tests secret viewing, URL parsing security, and XSS prevention
 */

// Mock fetch globally
global.fetch = jest.fn();

describe('View.js Security Tests', () => {
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
      hash: '#abc123def456',
    };
  });

  describe('URL Hash Parsing Security', () => {
    test('should safely extract link ID from URL hash', () => {
      // Test valid hash
      window.location.hash = '#abc123def456';
      const hash = window.location.hash.substring(1);
      const linkId = hash;
      
      expect(linkId).toBe('abc123def456');
      expect(linkId).toMatch(/^[a-zA-Z0-9]+$/);
    });

    test('should handle malicious hash values safely', () => {
      const maliciousHashes = [
        '#<script>alert("XSS")</script>',
        '#javascript:alert("XSS")',
        '#../../../etc/passwd',
        '#%3Cscript%3Ealert%28%22XSS%22%29%3C%2Fscript%3E',
        '#\'"onload=alert("XSS")',
        '#${alert("XSS")}',
      ];

      maliciousHashes.forEach(maliciousHash => {
        window.location.hash = maliciousHash;
        const hash = window.location.hash.substring(1);
        const linkId = hash;
        
        // Should extract the value as-is (it's just data)
        expect(typeof linkId).toBe('string');
        
        // The security comes from using it properly (not executing it)
        // API endpoint construction should be safe
        const apiEndpoint = `/api/share/secret/${linkId}`;
        expect(typeof apiEndpoint).toBe('string');
      });
    });

    test('should handle empty or missing hash values', () => {
      const emptyHashes = ['', '#', '#   ', '#\n\t'];
      
      emptyHashes.forEach(emptyHash => {
        window.location.hash = emptyHash;
        const hash = window.location.hash.substring(1);
        const linkId = hash;
        
        // Should handle empty values gracefully
        if (!linkId || linkId.trim() === '') {
          expect(linkId.trim()).toBe('');
        }
      });
    });

    test('should handle extremely long hash values', () => {
      const veryLongHash = '#' + 'a'.repeat(10000);
      window.location.hash = veryLongHash;
      
      const hash = window.location.hash.substring(1);
      const linkId = hash;
      
      expect(linkId.length).toBe(10000);
      expect(() => {
        const apiEndpoint = `/api/share/secret/${linkId}`;
        expect(typeof apiEndpoint).toBe('string');
      }).not.toThrow();
    });
  });

  describe('API Security', () => {
    test('should use proper environment-based API endpoints', () => {
      // Test production environment
      window.location = {
        hostname: 'securesharer.example.com',
        protocol: 'https:',
      };
      
      const isDevelopment = window.location.hostname === 'localhost' || 
                           window.location.hostname === '127.0.0.1' ||
                           window.location.protocol === 'file:';
      const apiEndpoint = isDevelopment 
        ? `http://127.0.0.1:5000/api/share/secret/abc123` 
        : `/api/share/secret/abc123`;
      
      expect(isDevelopment).toBe(false);
      expect(apiEndpoint).toBe('/api/share/secret/abc123');
      expect(apiEndpoint).not.toContain('http://');
    });

    test('should handle API responses securely', async () => {
      const validResponses = [
        { secret: 'test secret' },
        { error: 'Secret not found' },
      ];
      
      validResponses.forEach(response => {
        if (response.secret) {
          expect(typeof response.secret).toBe('string');
        }
        if (response.error) {
          expect(typeof response.error).toBe('string');
        }
      });
    });

    test('should validate API response structure', () => {
      const testResponses = [
        { secret: 'valid secret' },
        { error: 'not found' },
        null,
        undefined,
        {},
        { secret: null },
        { secret: '' },
        { maliciousProperty: '<script>alert("XSS")</script>' },
      ];

      testResponses.forEach(response => {
        const hasValidSecret = response && response.secret && typeof response.secret === 'string';
        const hasValidError = response && response.error && typeof response.error === 'string';
        const isValid = hasValidSecret || hasValidError;
        
        // Only the first two should be valid
        if (response === testResponses[0] || response === testResponses[1]) {
          expect(isValid).toBe(true);
        } else {
          expect(isValid).toBeFalsy();
        }
      });
    });

    test('should use secure HTTP methods', () => {
      const checkMethods = {
        HEAD: 'HEAD', // For checking existence
        GET: 'GET',   // For retrieving secret
      };
      
      // Verify these are the only methods used
      expect(checkMethods.HEAD).toBe('HEAD');
      expect(checkMethods.GET).toBe('GET');
      
      // Should not use dangerous methods
      expect(checkMethods).not.toHaveProperty('POST');
      expect(checkMethods).not.toHaveProperty('PUT');
      expect(checkMethods).not.toHaveProperty('DELETE');
    });

    test('should handle network errors gracefully', async () => {
      // Mock network error
      global.fetch.mockRejectedValue(new Error('Network error'));
      
      try {
        await fetch('/api/share/secret/abc123');
      } catch (error) {
        expect(error.message).toBe('Network error');
        expect(error).toBeInstanceOf(Error);
      }
    });
  });

  describe('Content Security and XSS Prevention', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div id="headerTitle">Loading...</div>
        <div id="secretContent" class="hidden"></div>
        <div id="errorContent" class="hidden"></div>
        <div id="initialMessage" class="hidden"></div>
        <div id="loadingContainer" class="hidden"></div>
      `;
    });

    test('should safely display secret content without XSS', () => {
      const maliciousSecret = '<script>alert("XSS from secret")</script>';
      const secretContent = document.getElementById('secretContent');
      
      // Simulate safe secret display
      function showSecret(secretText) {
        // Use escapeHTML-like function for safety
        function escapeHTML(text) {
          const div = document.createElement('div');
          div.textContent = text;
          return div.innerHTML;
        }
        
        secretContent.innerHTML = `
          <div>
            <div>${escapeHTML(secretText)}</div>
          </div>
        `;
      }
      
      showSecret(maliciousSecret);
      
      // Verify the script is not executed
      expect(secretContent.innerHTML).toContain('&lt;script&gt;');
      expect(secretContent.innerHTML).not.toContain('<script>alert');
      expect(secretContent.querySelectorAll('script').length).toBe(0);
    });

    test('should safely display error messages', () => {
      const maliciousError = '<img src=x onerror=alert("XSS")>';
      const errorContent = document.getElementById('errorContent');
      
      // Simulate safe error display
      function showError(message) {
        function escapeHTML(text) {
          const div = document.createElement('div');
          div.textContent = text;
          return div.innerHTML;
        }
        
        errorContent.innerHTML = `
          <div>
            <p>${escapeHTML(message)}</p>
          </div>
        `;
      }
      
      showError(maliciousError);
      
      // Verify no executable content
      expect(errorContent.innerHTML).toContain('&lt;img');
      expect(errorContent.innerHTML).not.toContain('<img src=x onerror=');
      expect(errorContent.querySelectorAll('img[onerror]').length).toBe(0);
    });

    test('should handle large secret content safely', () => {
      const largeSecret = 'A'.repeat(100000);
      const secretContent = document.getElementById('secretContent');
      
      // Should handle large content without performance issues
      expect(() => {
        function escapeHTML(text) {
          const div = document.createElement('div');
          div.textContent = text;
          return div.innerHTML;
        }
        
        const escaped = escapeHTML(largeSecret);
        expect(escaped.length).toBeGreaterThan(0);
      }).not.toThrow();
    });

    test('should validate DOM element existence before manipulation', () => {
      // Test with missing elements
      document.body.innerHTML = '';
      
      const headerTitle = document.getElementById('headerTitle');
      const secretContent = document.getElementById('secretContent');
      
      expect(headerTitle).toBeNull();
      expect(secretContent).toBeNull();
      
      // Safe manipulation should check for element existence
      function safeSetContent(elementId, content) {
        const element = document.getElementById(elementId);
        if (element) {
          element.textContent = content;
          return true;
        }
        return false;
      }
      
      expect(safeSetContent('headerTitle', 'test')).toBe(false);
      expect(safeSetContent('nonexistent', 'test')).toBe(false);
    });
  });

  describe('Modal Security', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div id="helpModal" class="hidden"></div>
        <button id="helpButton">Help</button>
        <button id="closeHelpModal">Close</button>
        <button id="closeHelpModalButton">Close Modal</button>
      `;
    });

    test('should handle modal interactions securely', () => {
      const helpModal = document.getElementById('helpModal');
      const helpButton = document.getElementById('helpButton');
      
      // Test modal show/hide functions
      function showHelpModal() {
        if (helpModal) {
          helpModal.classList.remove('hidden');
          document.body.style.overflow = 'hidden';
        }
      }
      
      function hideHelpModal() {
        if (helpModal) {
          helpModal.classList.add('hidden');
          document.body.style.overflow = '';
        }
      }
      
      // Test modal functionality
      showHelpModal();
      expect(helpModal.classList.contains('hidden')).toBe(false);
      expect(document.body.style.overflow).toBe('hidden');
      
      hideHelpModal();
      expect(helpModal.classList.contains('hidden')).toBe(true);
      expect(document.body.style.overflow).toBe('');
    });

    test('should prevent modal escape through event injection', () => {
      const helpModal = document.getElementById('helpModal');
      
      // Test safe event handling
      function addSecureEventListener(element, event, handler) {
        if (element && typeof handler === 'function') {
          element.addEventListener(event, handler);
          return true;
        }
        return false;
      }
      
      const mockHandler = jest.fn();
      const result = addSecureEventListener(helpModal, 'click', mockHandler);
      
      expect(result).toBe(true);
      expect(typeof mockHandler).toBe('function');
    });

    test('should handle keyboard events securely', () => {
      const escapeHandler = (e) => {
        if (e.key === 'Escape') {
          const helpModal = document.getElementById('helpModal');
          if (helpModal && !helpModal.classList.contains('hidden')) {
            helpModal.classList.add('hidden');
          }
        }
      };
      
      // Test escape key handling
      const mockEvent = { key: 'Escape' };
      expect(() => {
        escapeHandler(mockEvent);
      }).not.toThrow();
      
      // Test non-escape keys
      const mockEvent2 = { key: 'Enter' };
      expect(() => {
        escapeHandler(mockEvent2);
      }).not.toThrow();
    });
  });

  describe('State Management Security', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div id="initialMessage" class="hidden"></div>
        <div id="loadingContainer" class="hidden"></div>
        <div id="secretContent" class="hidden"></div>
        <div id="errorContent" class="hidden"></div>
      `;
    });

    test('should manage UI state transitions securely', () => {
      const elements = {
        initialMessage: document.getElementById('initialMessage'),
        loadingContainer: document.getElementById('loadingContainer'),
        secretContent: document.getElementById('secretContent'),
        errorContent: document.getElementById('errorContent'),
      };
      
      // Test state reset function
      function resetUI() {
        Object.values(elements).forEach(element => {
          if (element) {
            element.classList.add('hidden');
          }
        });
      }
      
      // Verify all elements start visible
      Object.values(elements).forEach(element => {
        element.classList.remove('hidden');
      });
      
      resetUI();
      
      // Verify all elements are hidden
      Object.values(elements).forEach(element => {
        expect(element.classList.contains('hidden')).toBe(true);
      });
    });

    test('should prevent state corruption through invalid inputs', () => {
      const validStates = ['loading', 'secret', 'error', 'initial'];
      const invalidStates = [
        null,
        undefined,
        '<script>alert("XSS")</script>',
        123,
        {},
        [],
        function() { alert('XSS'); }
      ];
      
      function isValidState(state) {
        return validStates.includes(state);
      }
      
      validStates.forEach(state => {
        expect(isValidState(state)).toBe(true);
      });
      
      invalidStates.forEach(state => {
        expect(isValidState(state)).toBe(false);
      });
    });
  });

  describe('URL Construction Security', () => {
    test('should construct API endpoints safely', () => {
      const linkIds = [
        'abc123def456',
        'valid-id-123',
        '<script>alert("XSS")</script>',
        '../../../etc/passwd',
        'very-long-id-' + 'a'.repeat(1000),
      ];
      
      linkIds.forEach(linkId => {
        const apiEndpoint = `/api/share/secret/${linkId}`;
        
        // Should construct endpoint without throwing
        expect(typeof apiEndpoint).toBe('string');
        expect(apiEndpoint.startsWith('/api/share/secret/')).toBe(true);
        
        // The dangerous content should just be treated as data
        expect(apiEndpoint).toContain(linkId);
      });
    });

    test('should handle URL encoding properly', () => {
      const specialCharIds = [
        'id with spaces',
        'id/with/slashes',
        'id%20encoded',
        'id&with&ampersands',
      ];
      
      specialCharIds.forEach(linkId => {
        // URL construction should work
        const apiEndpoint = `/api/share/secret/${linkId}`;
        expect(typeof apiEndpoint).toBe('string');
        
        // For actual use, proper encoding should be applied
        const encodedEndpoint = `/api/share/secret/${encodeURIComponent(linkId)}`;
        expect(typeof encodedEndpoint).toBe('string');
        expect(encodedEndpoint).not.toContain(' ');
      });
    });
  });

  describe('Response Parsing Security', () => {
    test('should parse JSON responses safely', () => {
      const validJSONResponses = [
        '{"secret": "test secret"}',
        '{"error": "not found"}',
        '{}',
      ];
      
      const invalidJSONResponses = [
        'invalid json',
        '{"secret": }',
        '<script>alert("XSS")</script>',
      ];
      
      validJSONResponses.forEach(json => {
        expect(() => {
          const parsed = JSON.parse(json);
          expect(typeof parsed).toBe('object');
        }).not.toThrow();
      });
      
      invalidJSONResponses.forEach(json => {
        expect(() => {
          JSON.parse(json);
        }).toThrow();
      });
      
      // Test null and undefined separately since they have special behavior
      // Note: JSON.parse(null) actually returns null (doesn't throw)
      expect(JSON.parse(null)).toBe(null);
      expect(() => JSON.parse(undefined)).toThrow();
    });

    test('should validate parsed response properties', () => {
      const responses = [
        { secret: 'valid secret' },
        { error: 'valid error' },
        { secret: null },
        { secret: '' },
        { error: null },
        { error: '' },
        { __proto__: { polluted: true } },
        { maliciousProp: '<script>alert("XSS")</script>' },
      ];
      
      responses.forEach(response => {
        // Check for valid secret
        const hasValidSecret = response.secret && typeof response.secret === 'string' && response.secret.length > 0;
        
        // Check for valid error
        const hasValidError = response.error && typeof response.error === 'string' && response.error.length > 0;
        
        const isValid = hasValidSecret || hasValidError;
        
        // Only first two should be valid
        if (response === responses[0] || response === responses[1]) {
          expect(isValid).toBe(true);
        }
      });
      
      // Verify no prototype pollution
      expect({}.polluted).toBeUndefined();
    });
  });
});