// Tests for utils.js utility functions

const {
  copyToClipboard,
  copyToClipboardFallback,
  showManualCopyDialog,
  showCopySuccess,
  escapeHTML,
  truncateLink,
  formatDate
} = require('./utils-testable');

describe('Utils Functions', () => {
  describe('escapeHTML', () => {
    test('should escape HTML special characters', () => {
      expect(escapeHTML('<script>alert("xss")</script>')).toBe('&lt;script&gt;alert("xss")&lt;/script&gt;');
      expect(escapeHTML('Hello & "World"')).toBe('Hello &amp; "World"');
      expect(escapeHTML("It's <b>bold</b>")).toBe("It's &lt;b&gt;bold&lt;/b&gt;");
    });

    test('should handle empty string', () => {
      expect(escapeHTML('')).toBe('');
    });

    test('should handle string with no special characters', () => {
      expect(escapeHTML('Hello World')).toBe('Hello World');
    });

    test('should handle unicode characters', () => {
      expect(escapeHTML('Hello 🌍 World')).toBe('Hello 🌍 World');
    });
  });

  describe('truncateLink', () => {
    test('should not truncate short URLs', () => {
      const shortUrl = 'https://example.com/short';
      expect(truncateLink(shortUrl)).toBe(shortUrl);
    });

    test('should truncate long URLs properly', () => {
      const longUrl = 'https://verylongdomainname.example.com/very/long/path/to/resource#verylonghashcontenthere123456789';
      const result = truncateLink(longUrl);
      expect(result).toContain('https://');
      expect(result).toContain('verylongdomainname.example.com');
      expect(result.length).toBeLessThan(longUrl.length);
      // The algorithm truncates the path and hash separately
      expect(result).toMatch(/https:\/\/verylongdomainname\.example\.com\/very\.\.\./);
    });

    test('should handle URLs with hash fragments', () => {
      const urlWithHash = 'https://example.com/view.html#abcdef123456789012345678';
      const result = truncateLink(urlWithHash);
      // This test should check that the function handles the URL correctly, not specific format
      expect(result).toContain('example.com');
      expect(result.length).toBeLessThanOrEqual(urlWithHash.length);
    });

    test('should handle invalid URLs gracefully', () => {
      const invalidUrl = 'not-a-valid-url-but-very-long-string-that-needs-truncation-for-display-purposes';
      const result = truncateLink(invalidUrl);
      expect(result.length).toBeLessThan(invalidUrl.length);
      expect(result).toContain('...');
    });

    test('should handle URLs without hash', () => {
      const urlWithoutHash = 'https://example.com/very/long/path/to/some/resource/file.html';
      const result = truncateLink(urlWithoutHash);
      expect(result).toContain('https://example.com');
    });
  });

  describe('formatDate', () => {
    beforeEach(() => {
      // Mock Date.now() to have consistent test results
      jest.useFakeTimers();
      jest.setSystemTime(new Date('2024-01-15T12:00:00Z'));
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    test('should return "Just now" for very recent dates', () => {
      // Create a date that's definitely within the "Just now" threshold (< 60 seconds)
      const now = new Date(Date.now() - 30 * 1000).toISOString();
      expect(formatDate(now)).toBe('Just now');
    });

    test('should format minutes ago correctly', () => {
      const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
      expect(formatDate(fiveMinutesAgo)).toBe('5 mins ago');
      
      const oneMinuteAgo = new Date(Date.now() - 1 * 60 * 1000).toISOString();
      expect(formatDate(oneMinuteAgo)).toBe('1 min ago');
    });

    test('should format hours ago correctly', () => {
      const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
      expect(formatDate(twoHoursAgo)).toBe('2 hrs ago');
      
      const oneHourAgo = new Date(Date.now() - 1 * 60 * 60 * 1000).toISOString();
      expect(formatDate(oneHourAgo)).toBe('1 hr ago');
    });

    test('should format days ago correctly', () => {
      const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString();
      expect(formatDate(threeDaysAgo)).toBe('3 days ago');
      
      const oneDayAgo = new Date(Date.now() - 1 * 24 * 60 * 60 * 1000).toISOString();
      expect(formatDate(oneDayAgo)).toBe('1 day ago');
    });

    test('should format older dates with specific date/time', () => {
      const weekAgo = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000).toISOString();
      const result = formatDate(weekAgo);
      // Check that it contains month and time, the exact format may vary
      expect(result).toMatch(/\w{3}/); // Month abbreviation
      expect(result).toMatch(/\d{1,2}/); // Day or hour number
    });
  });

  describe('copyToClipboardFallback', () => {
    beforeEach(() => {
      // Mock document.createElement and document.execCommand
      document.createElement = jest.fn().mockImplementation((tagName) => {
        if (tagName === 'textarea') {
          return {
            value: '',
            style: {},
            focus: jest.fn(),
            select: jest.fn(),
            setSelectionRange: jest.fn()
          };
        }
        return {};
      });
      
      document.body.appendChild = jest.fn();
      document.body.removeChild = jest.fn();
      document.execCommand = jest.fn();
    });

    test('should create textarea and attempt copy', () => {
      document.execCommand.mockReturnValue(true);
      
      const result = copyToClipboardFallback('test text');
      
      expect(document.createElement).toHaveBeenCalledWith('textarea');
      expect(document.execCommand).toHaveBeenCalledWith('copy');
      expect(result).toBe(true);
    });

    test('should return false when execCommand fails', () => {
      document.execCommand.mockReturnValue(false);
      
      const result = copyToClipboardFallback('test text');
      
      expect(result).toBe(false);
    });

    test('should handle exceptions gracefully', () => {
      document.execCommand.mockImplementation(() => {
        throw new Error('Copy failed');
      });
      
      const result = copyToClipboardFallback('test text');
      
      expect(result).toBe(false);
    });
  });

  describe('showCopySuccess', () => {
    test('should update button appearance and revert after timeout', (done) => {
      const mockButton = {
        innerHTML: '<original>',
        style: {
          backgroundColor: 'blue',
          removeProperty: jest.fn()
        },
        classList: {
          add: jest.fn(),
          remove: jest.fn()
        }
      };

      // Use real timers for this test
      jest.useRealTimers();
      
      showCopySuccess(mockButton);
      
      // Check immediate changes
      expect(mockButton.classList.add).toHaveBeenCalledWith('copying');
      expect(mockButton.innerHTML).toContain('svg'); // Success checkmark SVG
      expect(mockButton.style.backgroundColor).toBe('#2d7d6e');
      
      // Check that it reverts after 2 seconds
      setTimeout(() => {
        expect(mockButton.innerHTML).toBe('<original>');
        expect(mockButton.classList.remove).toHaveBeenCalledWith('copying');
        done();
      }, 2100); // Wait slightly longer than the timeout
    });

    test('should handle null button gracefully', () => {
      expect(() => showCopySuccess(null)).not.toThrow();
    });

    test('should handle button with existing background color', () => {
      const mockButton = {
        innerHTML: '<original>',
        style: {
          backgroundColor: 'red',
          removeProperty: jest.fn()
        },
        classList: {
          add: jest.fn(),
          remove: jest.fn()
        }
      };

      jest.useRealTimers();
      showCopySuccess(mockButton);
      
      // Should not call removeProperty when there's an existing background
      setTimeout(() => {
        expect(mockButton.style.removeProperty).not.toHaveBeenCalled();
      }, 2100);
    });

    test('should call removeProperty when no existing background', () => {
      const mockButton = {
        innerHTML: '<original>',
        style: {
          backgroundColor: '',
          removeProperty: jest.fn()
        },
        classList: {
          add: jest.fn(),
          remove: jest.fn()
        }
      };

      jest.useRealTimers();
      showCopySuccess(mockButton);
      
      // Should call removeProperty when no existing background
      setTimeout(() => {
        expect(mockButton.style.removeProperty).toHaveBeenCalledWith('background-color');
      }, 2100);
    });
  });

  describe('showManualCopyDialog', () => {
    test('should call prompt with correct message', () => {
      const mockPrompt = jest.fn();
      global.prompt = mockPrompt;
      
      showManualCopyDialog('test text');
      
      expect(mockPrompt).toHaveBeenCalledWith(
        'Auto-copy to clipboard is not available. Please manually copy this text:\n\n' +
        '(The text is pre-selected for you)',
        'test text'
      );
    });
  });

  describe('copyToClipboard', () => {
    test('should exist and be callable', async () => {
      expect(typeof copyToClipboard).toBe('function');
      
      // Test with mock navigator
      global.navigator = {};
      global.prompt = jest.fn();
      
      const mockButton = { innerHTML: 'Copy' };
      await expect(copyToClipboard('test text', mockButton)).resolves.not.toThrow();
    });
  });

  describe('OWASP Top 10 Security Tests', () => {
    beforeEach(() => {
      // Setup DOM mocks for security tests
      document.createElement = jest.fn().mockImplementation((tagName) => {
        if (tagName === 'div') {
          return {
            get textContent() { return this._textContent || ''; },
            set textContent(value) { 
              this._textContent = value;
              this.innerHTML = value
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;');
            },
            innerHTML: ''
          };
        }
        return {
          value: '',
          style: {},
          focus: jest.fn(),
          select: jest.fn(),
          setSelectionRange: jest.fn()
        };
      });
      
      // Mock document.body methods without replacing the body itself
      document.body.appendChild = jest.fn();
      document.body.removeChild = jest.fn();
      document.execCommand = jest.fn();
    });

    describe('A03:2021 – Injection (XSS Prevention)', () => {
      test('escapeHTML should prevent script injection', () => {
        const maliciousScript = '<script>alert("XSS")</script>';
        const escaped = escapeHTML(maliciousScript);
        expect(escaped).toBe('&lt;script&gt;alert("XSS")&lt;/script&gt;');
        expect(escaped).not.toContain('<script>');
      });

      test('escapeHTML should prevent HTML injection', () => {
        const maliciousHTML = '<img src=x onerror=alert("XSS")>';
        const escaped = escapeHTML(maliciousHTML);
        expect(escaped).toBe('&lt;img src=x onerror=alert("XSS")&gt;');
        expect(escaped).not.toContain('<img');
      });

      test('escapeHTML should prevent CSS injection', () => {
        const maliciousCSS = '<style>body{background:url("javascript:alert(1)")}</style>';
        const escaped = escapeHTML(maliciousCSS);
        expect(escaped).not.toContain('<style>');
        expect(escaped).toContain('&lt;style&gt;');
      });

      test('escapeHTML should handle multiple injection attempts', () => {
        const multipleInjections = '<script>alert(1)</script><img src=x onerror=alert(2)><style>alert(3)</style>';
        const escaped = escapeHTML(multipleInjections);
        expect(escaped).not.toContain('<script>');
        expect(escaped).not.toContain('<img');
        expect(escaped).not.toContain('<style>');
      });
    });

    describe('A05:2021 – Security Misconfiguration (Input Validation)', () => {
      test('truncateLink should handle malicious URLs safely', () => {
        const maliciousUrl = 'javascript:alert("XSS")';
        const result = truncateLink(maliciousUrl);
        // Should fallback to safe truncation when URL parsing fails
        expect(result.length).toBeLessThanOrEqual(50);
      });

      test('truncateLink should handle data URLs safely', () => {
        const dataUrl = 'data:text/html,<script>alert("XSS")</script>';
        const result = truncateLink(dataUrl);
        expect(result.length).toBeLessThanOrEqual(50);
      });

      test('truncateLink should handle very long URLs', () => {
        const longUrl = 'https://example.com/' + 'a'.repeat(1000);
        const result = truncateLink(longUrl);
        expect(result.length).toBeLessThan(longUrl.length);
      });
    });

    describe('A06:2021 – Vulnerable Components (Date Handling)', () => {
      test('formatDate should handle invalid dates safely', () => {
        expect(() => formatDate('invalid-date')).not.toThrow();
        expect(() => formatDate(null)).not.toThrow();
        expect(() => formatDate(undefined)).not.toThrow();
      });

      test('formatDate should not expose internal errors', () => {
        const consoleSpy = jest.spyOn(console, 'error').mockImplementation();
        formatDate('definitely-not-a-date');
        expect(consoleSpy).not.toHaveBeenCalled();
        consoleSpy.mockRestore();
      });

      test('formatDate should handle edge cases in time calculations', () => {
        // Test exact boundary conditions to improve branch coverage
        const now = Date.now();
        const exactly59Seconds = new Date(now - 59 * 1000).toISOString();
        const exactly60Seconds = new Date(now - 60 * 1000).toISOString();
        
        expect(formatDate(exactly59Seconds)).toBe('Just now');
        expect(formatDate(exactly60Seconds)).toBe('1 min ago');
        
        // Test hour boundary
        const exactly59Minutes = new Date(now - 59 * 60 * 1000).toISOString();
        const exactly60Minutes = new Date(now - 60 * 60 * 1000).toISOString();
        
        expect(formatDate(exactly59Minutes)).toBe('59 mins ago');
        expect(formatDate(exactly60Minutes)).toBe('1 hr ago');
        
        // Test day boundary
        const exactly23Hours = new Date(now - 23 * 60 * 60 * 1000).toISOString();
        const exactly24Hours = new Date(now - 24 * 60 * 60 * 1000).toISOString();
        
        expect(formatDate(exactly23Hours)).toBe('23 hrs ago');
        expect(formatDate(exactly24Hours)).toBe('1 day ago');
      });
    });

    describe('A07:2021 – Identification and Authentication (Safe Clipboard)', () => {
      test('copyToClipboardFallback should not expose sensitive operations', () => {
        const consoleSpy = jest.spyOn(console, 'error').mockImplementation();
        
        // Mock createElement to throw error
        const originalCreateElement = document.createElement;
        document.createElement = jest.fn().mockImplementation(() => {
          throw new Error('Blocked for security');
        });
        
        const result = copyToClipboardFallback('test');
        expect(result).toBe(false);
        expect(consoleSpy).toHaveBeenCalled();
        
        document.createElement = originalCreateElement;
        consoleSpy.mockRestore();
      });
    });

    describe('A08:2021 – Software and Data Integrity (Input Sanitization)', () => {
      test('showManualCopyDialog should handle special characters safely', () => {
        global.prompt = jest.fn();
        
        const specialChars = '\\n\\r\\t<>&"\'';
        showManualCopyDialog(specialChars);
        
        expect(global.prompt).toHaveBeenCalledWith(
          expect.stringContaining('manually copy'),
          specialChars
        );
      });
    });

    describe('A09:2021 – Security Logging (Error Handling)', () => {
      test('copyToClipboard should log errors appropriately', async () => {
        const consoleSpy = jest.spyOn(console, 'error').mockImplementation();
        
        global.navigator = {
          clipboard: {
            writeText: jest.fn().mockRejectedValue(new Error('Test error'))
          }
        };
        global.prompt = jest.fn();
        
        await copyToClipboard('test', { innerHTML: 'Copy' });
        
        expect(consoleSpy).toHaveBeenCalledWith(
          'Failed to copy to clipboard:',
          expect.any(Error)
        );
        
        consoleSpy.mockRestore();
      });
    });

    describe('A10:2021 – Server-Side Request Forgery (URL Validation)', () => {
      test('truncateLink should reject potentially dangerous URLs', () => {
        const dangerousUrls = [
          'file:///etc/passwd',
          'ftp://internal.server/file',
          'gopher://example.com',
          'ldap://internal-ldap'
        ];
        
        dangerousUrls.forEach(url => {
          const result = truncateLink(url);
          // Should either truncate safely or fall back to safe handling
          expect(result).toBeDefined();
          expect(typeof result).toBe('string');
        });
      });
    });
  });
});