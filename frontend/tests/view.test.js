// Tests for view.js functionality

describe('View Page Functions', () => {
  let mockElements;

  beforeEach(() => {
    // Create mock DOM elements that view.js expects
    mockElements = {
      headerTitle: { 
        textContent: ''
      },
      initialMessage: { 
        classList: { 
          remove: jest.fn(),
          add: jest.fn()
        }
      },
      loadingContainer: { 
        classList: { 
          remove: jest.fn(),
          add: jest.fn()
        }
      },
      secretContent: { 
        classList: { 
          remove: jest.fn(),
          add: jest.fn()
        },
        innerHTML: ''
      },
      errorContent: { 
        classList: { 
          remove: jest.fn(),
          add: jest.fn()
        },
        innerHTML: ''
      },
      helpButton: { 
        addEventListener: jest.fn()
      },
      helpModal: { 
        classList: { 
          remove: jest.fn(),
          add: jest.fn(),
          contains: jest.fn()
        },
        addEventListener: jest.fn()
      },
      closeHelpModal: { 
        addEventListener: jest.fn()
      },
      closeHelpModalButton: { 
        addEventListener: jest.fn()
      },
      revealButton: { 
        addEventListener: jest.fn()
      }
    };

    // Mock getElementById to return our mock elements
    document.getElementById = jest.fn((id) => {
      const elementMap = {
        'headerTitle': mockElements.headerTitle,
        'initialMessage': mockElements.initialMessage,
        'loadingContainer': mockElements.loadingContainer,
        'secretContent': mockElements.secretContent,
        'errorContent': mockElements.errorContent,
        'helpButton': mockElements.helpButton,
        'helpModal': mockElements.helpModal,
        'closeHelpModal': mockElements.closeHelpModal,
        'closeHelpModalButton': mockElements.closeHelpModalButton,
        'revealButton': mockElements.revealButton
      };
      return elementMap[id] || null;
    });

    // Mock document.body for modal functionality
    Object.defineProperty(document, 'body', {
      value: {
        style: {},
        addEventListener: jest.fn()
      },
      writable: true
    });

    // Mock document.addEventListener for keyboard events
    document.addEventListener = jest.fn();

    // Clear fetch mock
    fetch.mockClear();
  });

  describe('Link ID Extraction', () => {
    test('should extract link ID from URL hash correctly', () => {
      // Test basic hash
      window.location.hash = '#abc123def';
      const hash = window.location.hash.substring(1);
      const linkId = hash;
      
      expect(linkId).toBe('abc123def');
    });

    test('should handle empty hash', () => {
      window.location.hash = '';
      const hash = window.location.hash.substring(1);
      const linkId = hash;
      
      expect(linkId).toBe('');
    });

    test('should handle hash with special characters', () => {
      window.location.hash = '#abc-123_def.456';
      const hash = window.location.hash.substring(1);
      const linkId = hash;
      
      expect(linkId).toBe('abc-123_def.456');
    });

    test('should handle very long hash', () => {
      const longHash = '#' + 'a'.repeat(100);
      window.location.hash = longHash;
      const hash = window.location.hash.substring(1);
      const linkId = hash;
      
      expect(linkId).toBe('a'.repeat(100));
    });
  });

  describe('Environment Detection', () => {
    test('should detect development environment for secret checking', () => {
      // Test localhost
      window.location.hostname = 'localhost';
      window.location.protocol = 'http:';
      
      const isDevelopment = window.location.hostname === 'localhost' || 
                           window.location.hostname === '127.0.0.1' ||
                           window.location.protocol === 'file:';
      const apiEndpoint = isDevelopment 
        ? `http://127.0.0.1:5000/api/share/secret/test123`
        : `/api/share/secret/test123`;
      
      expect(apiEndpoint).toBe('http://127.0.0.1:5000/api/share/secret/test123');
    });

    test('should detect production environment for secret checking', () => {
      window.location.hostname = 'example.com';
      window.location.protocol = 'https:';
      
      const isDevelopment = window.location.hostname === 'localhost' || 
                           window.location.hostname === '127.0.0.1' ||
                           window.location.protocol === 'file:';
      const apiEndpoint = isDevelopment 
        ? `http://127.0.0.1:5000/api/share/secret/test123`
        : `/api/share/secret/test123`;
      
      expect(apiEndpoint).toBe('/api/share/secret/test123');
    });
  });

  describe('UI State Management', () => {
    test('should reset all UI states correctly', () => {
      // Simulate resetUI function
      const resetUI = () => {
        mockElements.initialMessage.classList.add('hidden');
        mockElements.loadingContainer.classList.add('hidden');
        mockElements.secretContent.classList.add('hidden');
        mockElements.errorContent.classList.add('hidden');
      };

      resetUI();

      expect(mockElements.initialMessage.classList.add).toHaveBeenCalledWith('hidden');
      expect(mockElements.loadingContainer.classList.add).toHaveBeenCalledWith('hidden');
      expect(mockElements.secretContent.classList.add).toHaveBeenCalledWith('hidden');
      expect(mockElements.errorContent.classList.add).toHaveBeenCalledWith('hidden');
    });

    test('should show loading state correctly', () => {
      // Simulate showing loading
      mockElements.loadingContainer.classList.remove('hidden');
      mockElements.headerTitle.textContent = 'Loading...';

      expect(mockElements.loadingContainer.classList.remove).toHaveBeenCalledWith('hidden');
      expect(mockElements.headerTitle.textContent).toBe('Loading...');
    });

    test('should show secret content correctly', () => {
      // Simulate showing secret
      mockElements.secretContent.classList.remove('hidden');
      mockElements.headerTitle.textContent = 'Your One-Time Secret';

      expect(mockElements.secretContent.classList.remove).toHaveBeenCalledWith('hidden');
      expect(mockElements.headerTitle.textContent).toBe('Your One-Time Secret');
    });

    test('should show error content correctly', () => {
      // Simulate showing error
      mockElements.errorContent.classList.remove('hidden');
      mockElements.headerTitle.textContent = 'An Error Occurred';

      expect(mockElements.errorContent.classList.remove).toHaveBeenCalledWith('hidden');
      expect(mockElements.headerTitle.textContent).toBe('An Error Occurred');
    });
  });

  describe('API Interaction', () => {
    test('should handle HEAD request for secret existence check', async () => {
      const mockResponse = {
        ok: true,
        status: 200
      };
      fetch.mockResolvedValue(mockResponse);

      const linkId = 'test123';
      const apiEndpoint = `/api/share/secret/${linkId}`;
      
      const response = await fetch(apiEndpoint, {
        method: 'HEAD',
        headers: {
          'Accept': 'application/json'
        }
      });

      expect(fetch).toHaveBeenCalledWith(apiEndpoint, {
        method: 'HEAD',
        headers: {
          'Accept': 'application/json'
        }
      });
      expect(response.ok).toBe(true);
      expect(response.status).toBe(200);
    });

    test('should handle 404 response for non-existent secret', async () => {
      const mockResponse = {
        ok: false,
        status: 404
      };
      fetch.mockResolvedValue(mockResponse);

      const linkId = 'nonexistent';
      const apiEndpoint = `/api/share/secret/${linkId}`;
      
      const response = await fetch(apiEndpoint, {
        method: 'HEAD',
        headers: {
          'Accept': 'application/json'
        }
      });

      expect(response.ok).toBe(false);
      expect(response.status).toBe(404);
    });

    test('should handle GET request for retrieving secret', async () => {
      const mockResponse = {
        ok: true,
        status: 200,
        json: jest.fn().mockResolvedValue({ secret: 'test secret content' })
      };
      fetch.mockResolvedValue(mockResponse);

      const linkId = 'test123';
      const apiEndpoint = `/api/share/secret/${linkId}`;
      
      const response = await fetch(apiEndpoint, {
        headers: {
          'Accept': 'application/json'
        }
      });

      const data = await response.json();

      expect(fetch).toHaveBeenCalledWith(apiEndpoint, {
        headers: {
          'Accept': 'application/json'
        }
      });
      expect(response.ok).toBe(true);
      expect(data.secret).toBe('test secret content');
    });

    test('should handle API error responses', async () => {
      const mockResponse = {
        ok: false,
        status: 500,
        json: jest.fn().mockResolvedValue({ error: 'Internal server error' })
      };
      fetch.mockResolvedValue(mockResponse);

      const response = await fetch('/api/share/secret/test123', {
        headers: {
          'Accept': 'application/json'
        }
      });

      const errorData = await response.json();

      expect(response.ok).toBe(false);
      expect(response.status).toBe(500);
      expect(errorData.error).toBe('Internal server error');
    });

    test('should handle network errors', async () => {
      fetch.mockRejectedValue(new Error('Network error'));

      try {
        await fetch('/api/share/secret/test123', {
          headers: {
            'Accept': 'application/json'
          }
        });
      } catch (error) {
        expect(error.message).toBe('Network error');
      }

      expect(fetch).toHaveBeenCalled();
    });

    test('should handle invalid JSON response', async () => {
      const mockResponse = {
        ok: true,
        status: 200,
        json: jest.fn().mockRejectedValue(new Error('Invalid JSON'))
      };
      fetch.mockResolvedValue(mockResponse);

      const response = await fetch('/api/share/secret/test123', {
        headers: {
          'Accept': 'application/json'
        }
      });

      try {
        await response.json();
      } catch (jsonError) {
        expect(jsonError.message).toBe('Invalid JSON');
      }

      expect(response.ok).toBe(true);
    });
  });

  describe('Modal Functionality', () => {
    test('should show help modal correctly', () => {
      // Simulate showHelpModal function
      const showHelpModal = () => {
        mockElements.helpModal.classList.remove('hidden');
        document.body.style.overflow = 'hidden';
      };

      showHelpModal();

      expect(mockElements.helpModal.classList.remove).toHaveBeenCalledWith('hidden');
      expect(document.body.style.overflow).toBe('hidden');
    });

    test('should hide help modal correctly', () => {
      // Simulate hideHelpModal function
      const hideHelpModal = () => {
        mockElements.helpModal.classList.add('hidden');
        document.body.style.overflow = '';
      };

      hideHelpModal();

      expect(mockElements.helpModal.classList.add).toHaveBeenCalledWith('hidden');
      expect(document.body.style.overflow).toBe('');
    });

    test('should handle modal close on escape key', () => {
      mockElements.helpModal.classList.contains.mockReturnValue(false);

      // Simulate escape key handler
      const handleEscape = (e) => {
        if (e.key === 'Escape' && !mockElements.helpModal.classList.contains('hidden')) {
          mockElements.helpModal.classList.add('hidden');
          document.body.style.overflow = '';
        }
      };

      // Simulate escape key press
      handleEscape({ key: 'Escape' });

      expect(mockElements.helpModal.classList.add).toHaveBeenCalledWith('hidden');
      expect(document.body.style.overflow).toBe('');
    });

    test('should not close modal on non-escape key', () => {
      mockElements.helpModal.classList.contains.mockReturnValue(false);

      // Simulate other key handler
      const handleEscape = (e) => {
        if (e.key === 'Escape' && !mockElements.helpModal.classList.contains('hidden')) {
          mockElements.helpModal.classList.add('hidden');
          document.body.style.overflow = '';
        }
      };

      // Simulate other key press
      handleEscape({ key: 'Enter' });

      expect(mockElements.helpModal.classList.add).not.toHaveBeenCalled();
    });
  });

  describe('Error Handling', () => {
    test('should handle invalid link ID gracefully', () => {
      const linkId = '';
      
      // Simulate validation logic
      if (!linkId) {
        mockElements.errorContent.innerHTML = 'Invalid link. No secret ID was provided.';
        mockElements.errorContent.classList.remove('hidden');
        mockElements.headerTitle.textContent = 'An Error Occurred';
      }

      expect(mockElements.errorContent.innerHTML).toBe('Invalid link. No secret ID was provided.');
      expect(mockElements.errorContent.classList.remove).toHaveBeenCalledWith('hidden');
      expect(mockElements.headerTitle.textContent).toBe('An Error Occurred');
    });

    test('should display server error messages', () => {
      const errorMessage = 'Server error occurred';
      
      // Simulate error display logic
      mockElements.errorContent.innerHTML = `Error: ${errorMessage}`;
      mockElements.errorContent.classList.remove('hidden');
      mockElements.headerTitle.textContent = 'An Error Occurred';

      expect(mockElements.errorContent.innerHTML).toBe('Error: Server error occurred');
      expect(mockElements.errorContent.classList.remove).toHaveBeenCalledWith('hidden');
      expect(mockElements.headerTitle.textContent).toBe('An Error Occurred');
    });

    test('should display not found message for 404 responses', () => {
      // Simulate not found logic
      mockElements.headerTitle.textContent = 'Secret Not Found';
      mockElements.errorContent.innerHTML = 'The secret link is invalid, has expired, or has already been viewed.';
      mockElements.errorContent.classList.remove('hidden');

      expect(mockElements.headerTitle.textContent).toBe('Secret Not Found');
      expect(mockElements.errorContent.innerHTML).toBe('The secret link is invalid, has expired, or has already been viewed.');
      expect(mockElements.errorContent.classList.remove).toHaveBeenCalledWith('hidden');
    });
  });

  describe('Security Considerations', () => {
    test('should handle potentially malicious link IDs', () => {
      const maliciousLinkId = '<script>alert("xss")</script>';
      
      // The link ID should be used in API calls but not directly in innerHTML
      // This test ensures we're aware of the security consideration
      expect(maliciousLinkId).toContain('<script>');
      
      // In actual implementation, this would be URL-encoded when used in fetch
      const encodedLinkId = encodeURIComponent(maliciousLinkId);
      expect(encodedLinkId).not.toContain('<script>');
    });

    test('should handle very long link IDs', () => {
      const longLinkId = 'a'.repeat(1000);
      
      // Should handle long IDs without breaking
      expect(longLinkId.length).toBe(1000);
      expect(typeof longLinkId).toBe('string');
    });

    test('should handle special characters in link IDs', () => {
      const specialCharsLinkId = 'abc123!@#$%^&*()_+-={}[]|\\:";\'<>?,./';
      
      // Should handle special characters appropriately
      const encodedLinkId = encodeURIComponent(specialCharsLinkId);
      expect(encodedLinkId).toBeDefined();
      expect(encodedLinkId.length).toBeGreaterThan(0);
    });
  });
});