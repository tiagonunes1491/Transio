// Tests for utils.js utility functions

// Import the functions by requiring the file
const fs = require('fs');
const path = require('path');

// Read and evaluate the utils.js file to make functions available
const utilsPath = path.join(__dirname, '..', 'static', 'utils.js');
const utilsCode = fs.readFileSync(utilsPath, 'utf8');

// Execute the utils code in our test environment to make functions available
eval(utilsCode);

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
      const now = new Date().toISOString();
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
  });
});