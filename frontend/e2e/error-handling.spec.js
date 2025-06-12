// error-handling.spec.js - E2E tests for error scenarios and edge cases

const { test, expect } = require('@playwright/test');
const {
  APIHelper,
  PageHelper,
  AssertionHelper,
  TestDataHelper,
  BrowserHelper
} = require('./helpers/test-helpers');

test.describe('Error Handling and Edge Cases', () => {
  test.beforeEach(async ({ page }) => {
    await BrowserHelper.clearLocalStorage(page);
  });

  test.describe('Network Error Scenarios', () => {
    test('should handle complete network failure', async ({ page }) => {
      // Disable all network access
      await BrowserHelper.disableNetworkAccess(page);
      
      await PageHelper.navigateToHome(page);
      
      // Try to create a secret - should handle network error gracefully
      await PageHelper.fillSecretMessage(page, 'Test message');
      await PageHelper.clickCreateLink(page);
      
      // Should not show success result area
      await new Promise(resolve => setTimeout(resolve, 2000)); // Wait for timeout
      await AssertionHelper.assertElementNotVisible(page, '#resultArea');
    });

    test('should handle slow network connections', async ({ page }) => {
      // Simulate very slow network
      await BrowserHelper.simulateSlowNetwork(page, 3000);
      
      await APIHelper.mockSecretCreation(page);
      await PageHelper.navigateToHome(page);
      
      await PageHelper.fillSecretMessage(page, 'Test message');
      const button = await PageHelper.clickCreateLink(page);
      
      // Should show loading state for extended period
      await expect(button).toContainText('Encrypting & Creating...');
      await expect(button).toBeDisabled();
      
      // Eventually should complete
      await PageHelper.waitForResultArea(page);
    });

    test('should handle API server errors', async ({ page }) => {
      // Mock various API error responses
      await APIHelper.mockAPIError(page, 'share', 500, 'Internal Server Error');
      
      await PageHelper.navigateToHome(page);
      await PageHelper.fillSecretMessage(page, 'Test message');
      await PageHelper.clickCreateLink(page);
      
      // Should handle error gracefully (implementation specific)
      await new Promise(resolve => setTimeout(resolve, 1000));
      await AssertionHelper.assertElementNotVisible(page, '#resultArea');
    });

    test('should handle API rate limiting', async ({ page }) => {
      await APIHelper.mockAPIError(page, 'share', 429, 'Too Many Requests');
      
      await PageHelper.navigateToHome(page);
      await PageHelper.fillSecretMessage(page, 'Test message');
      await PageHelper.clickCreateLink(page);
      
      // Should handle rate limiting appropriately
      await new Promise(resolve => setTimeout(resolve, 1000));
      await AssertionHelper.assertElementNotVisible(page, '#resultArea');
    });
  });

  test.describe('Invalid Input Scenarios', () => {
    test('should handle extremely long secret messages', async ({ page }) => {
      const veryLongMessage = TestDataHelper.generateLongSecret(100000); // 100KB
      
      await APIHelper.mockSecretCreation(page);
      await PageHelper.navigateToHome(page);
      
      await PageHelper.fillSecretMessage(page, veryLongMessage);
      await PageHelper.clickCreateLink(page);
      
      // Should either succeed or fail gracefully
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      // Check if result area appears or if there's appropriate handling
      const resultVisible = await page.locator('#resultArea').isVisible();
      const inputFocused = await page.locator('#secretMessageInput').isFocused();
      
      // One of these should be true - either success or validation
      expect(resultVisible || inputFocused).toBe(true);
    });

    test('should handle whitespace-only input', async ({ page }) => {
      await PageHelper.navigateToHome(page);
      
      // Test various whitespace scenarios
      const whitespaceInputs = ['   ', '\t\t\t', '\n\n\n', '  \t\n  '];
      
      for (const input of whitespaceInputs) {
        await PageHelper.fillSecretMessage(page, input);
        await PageHelper.clickCreateLink(page);
        
        // Should treat as empty and focus back to input
        await expect(page.locator('#secretMessageInput')).toBeFocused();
        
        // Result area should not appear
        await AssertionHelper.assertElementNotVisible(page, '#resultArea');
      }
    });

    test('should handle null bytes and control characters', async ({ page }) => {
      const controlCharMessage = 'Test\x00\x01\x02\x03\x04\x05message';
      
      await APIHelper.mockSecretCreation(page);
      await PageHelper.navigateToHome(page);
      
      await PageHelper.fillSecretMessage(page, controlCharMessage);
      await PageHelper.clickCreateLink(page);
      
      // Should handle control characters gracefully
      await AssertionHelper.assertSecretCreationSuccess(page);
    });

    test('should handle binary data input', async ({ page }) => {
      // Simulate binary data as string
      const binaryData = Array.from({length: 1000}, () => 
        String.fromCharCode(Math.floor(Math.random() * 256))
      ).join('');
      
      await APIHelper.mockSecretCreation(page);
      await PageHelper.navigateToHome(page);
      
      await PageHelper.fillSecretMessage(page, binaryData);
      await PageHelper.clickCreateLink(page);
      
      // Should handle binary data appropriately
      await AssertionHelper.assertSecretCreationSuccess(page);
    });
  });

  test.describe('Browser Compatibility Issues', () => {
    test('should handle missing localStorage', async ({ page }) => {
      // Simulate localStorage being unavailable
      await page.addInitScript(() => {
        delete window.localStorage;
      });
      
      await PageHelper.navigateToHome(page);
      
      // App should still function without localStorage
      const secretInput = page.locator('#secretMessageInput');
      await expect(secretInput).toBeVisible();
      
      // Should be able to create secrets
      await APIHelper.mockSecretCreation(page);
      await PageHelper.fillSecretMessage(page, 'Test without localStorage');
      await PageHelper.clickCreateLink(page);
      
      await AssertionHelper.assertSecretCreationSuccess(page);
    });

    test('should handle missing clipboard API', async ({ page }) => {
      // Simulate missing clipboard API
      await page.addInitScript(() => {
        delete navigator.clipboard;
      });
      
      await APIHelper.mockSecretCreation(page);
      await PageHelper.navigateToHome(page);
      
      await PageHelper.fillSecretMessage(page, 'Test without clipboard');
      await PageHelper.clickCreateLink(page);
      await PageHelper.waitForResultArea(page);
      
      // Copy button should still be present (may use fallback)
      const copyButton = page.locator('#copyLinkButton');
      await expect(copyButton).toBeVisible();
      
      // Clicking shouldn't cause errors
      await copyButton.click();
    });

    test('should handle missing fetch API', async ({ page }) => {
      // Simulate missing fetch API
      await page.addInitScript(() => {
        delete window.fetch;
      });
      
      await PageHelper.navigateToHome(page);
      
      // Should handle missing fetch gracefully
      await PageHelper.fillSecretMessage(page, 'Test without fetch');
      await PageHelper.clickCreateLink(page);
      
      // Should either use fallback or show appropriate error
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // App shouldn't crash
      const body = page.locator('body');
      await expect(body).toBeVisible();
    });
  });

  test.describe('Memory and Performance Edge Cases', () => {
    test('should handle rapid successive secret creations', async ({ page }) => {
      await APIHelper.mockSecretCreation(page);
      await PageHelper.navigateToHome(page);
      
      // Create multiple secrets rapidly
      for (let i = 0; i < 5; i++) {
        await PageHelper.fillSecretMessage(page, `Rapid test message ${i}`);
        await PageHelper.clickCreateLink(page);
        
        // Wait briefly between creations
        await new Promise(resolve => setTimeout(resolve, 100));
        
        // Clear for next iteration
        await page.locator('#secretMessageInput').fill('');
      }
      
      // App should remain stable
      const secretInput = page.locator('#secretMessageInput');
      await expect(secretInput).toBeVisible();
    });

    test('should handle memory-intensive operations', async ({ page }) => {
      // Create large amount of data in localStorage
      const largeDataArray = Array.from({length: 1000}, (_, i) => ({
        id: `test-id-${i}`,
        link: `http://127.0.0.1:3000/view.html#test-id-${i}`,
        timestamp: Date.now() - (i * 1000),
        viewed: false
      }));
      
      await BrowserHelper.setLocalStorageData(page, 'secretSharerLinks', JSON.stringify(largeDataArray));
      
      await PageHelper.navigateToHome(page);
      
      // App should load despite large localStorage data
      const secretInput = page.locator('#secretMessageInput');
      await expect(secretInput).toBeVisible();
      
      // Should handle the large dataset
      const historySection = page.locator('#historySection');
      await expect(historySection).toBeVisible();
    });
  });

  test.describe('Security Edge Cases', () => {
    test('should prevent XSS in secret input', async ({ page }) => {
      const xssPayload = '<script>window.xssTriggered = true;</script>';
      
      await APIHelper.mockSecretCreation(page);
      await PageHelper.navigateToHome(page);
      
      await PageHelper.fillSecretMessage(page, xssPayload);
      await PageHelper.clickCreateLink(page);
      
      await AssertionHelper.assertSecretCreationSuccess(page);
      
      // Verify XSS didn't execute
      const xssTriggered = await page.evaluate(() => window.xssTriggered);
      expect(xssTriggered).toBeFalsy();
    });

    test('should handle malicious URLs in generated links', async ({ page }) => {
      // Mock API to return potentially malicious link
      const maliciousResponse = {
        id: 'test-id',
        link: 'javascript:alert("XSS")',
        message: 'Secret created'
      };
      
      await APIHelper.mockSecretCreation(page, maliciousResponse);
      await PageHelper.navigateToHome(page);
      
      await PageHelper.fillSecretMessage(page, 'Test message');
      await PageHelper.clickCreateLink(page);
      
      // App should sanitize or handle malicious URLs
      const linkInput = page.locator('#secretLinkInput');
      await expect(linkInput).toBeVisible();
      
      const linkValue = await linkInput.inputValue();
      expect(linkValue).not.toContain('javascript:');
    });

    test('should prevent prototype pollution in localStorage', async ({ page }) => {
      // Attempt prototype pollution via localStorage
      const pollutionAttempt = '{"__proto__": {"polluted": "yes"}}';
      
      await page.evaluate((data) => {
        try {
          localStorage.setItem('secretSharerLinks', data);
        } catch (e) {
          // Ignore errors for this test
        }
      }, pollutionAttempt);
      
      await PageHelper.navigateToHome(page);
      
      // Check that prototype wasn't polluted
      const prototypePolluted = await page.evaluate(() => {
        return Object.prototype.polluted;
      });
      
      expect(prototypePolluted).toBeUndefined();
    });
  });

  test.describe('URL and Hash Handling Edge Cases', () => {
    test('should handle malformed URL hashes', async ({ page }) => {
      const malformedHashes = [
        '#',
        '#/',
        '#?query=value',
        '#fragment#nested',
        '#%00%01%02',
        '#' + 'x'.repeat(10000)
      ];
      
      for (const hash of malformedHashes) {
        await page.goto(`/view.html${hash}`);
        
        // Should handle malformed hash gracefully
        const body = page.locator('body');
        await expect(body).toBeVisible();
        
        // Should show appropriate error or handle gracefully
        const errorContent = page.locator('#errorContent');
        const initialMessage = page.locator('#initialMessage');
        
        // One of these should be visible (error or loading state)
        const errorVisible = await errorContent.isVisible();
        const messageVisible = await initialMessage.isVisible();
        
        expect(errorVisible || messageVisible).toBe(true);
      }
    });

    test('should handle URL encoding in secret IDs', async ({ page }) => {
      const encodedId = encodeURIComponent('test+id/with=special&chars');
      
      await APIHelper.mockSecretExists(page, true);
      await PageHelper.navigateToSecretView(page, encodedId);
      
      // Should decode and handle properly
      const initialMessage = page.locator('#initialMessage');
      await expect(initialMessage).toBeVisible();
    });
  });

  test.describe('Concurrent Operation Edge Cases', () => {
    test('should handle multiple tabs accessing same secret', async ({ context }) => {
      // Create two tabs
      const page1 = await context.newPage();
      const page2 = await context.newPage();
      
      const secretId = 'concurrent-test-id';
      
      // Mock different responses for each tab
      await APIHelper.mockSecretExists(page1, true);
      await APIHelper.mockSecretReveal(page1, {
        id: secretId,
        content: 'Secret content',
        created_at: new Date().toISOString()
      });
      
      await APIHelper.mockSecretExists(page2, true);
      await APIHelper.mockSecretReveal(page2, null, false); // Already viewed
      
      // Navigate both tabs to the same secret
      await PageHelper.navigateToSecretView(page1, secretId);
      await PageHelper.navigateToSecretView(page2, secretId);
      
      // First tab reveals secret
      await PageHelper.clickRevealSecret(page1);
      await AssertionHelper.assertSecretViewSuccess(page1, 'Secret content');
      
      // Second tab should get error (already viewed)
      await PageHelper.clickRevealSecret(page2);
      await AssertionHelper.assertError(page2);
      
      await page1.close();
      await page2.close();
    });

    test('should handle localStorage conflicts between tabs', async ({ context }) => {
      const page1 = await context.newPage();
      const page2 = await context.newPage();
      
      // Set different localStorage data in each tab
      await BrowserHelper.setLocalStorageData(page1, 'secretSharerLinks', JSON.stringify([
        { id: 'tab1-secret', link: 'http://example.com/1', timestamp: Date.now() }
      ]));
      
      await BrowserHelper.setLocalStorageData(page2, 'secretSharerLinks', JSON.stringify([
        { id: 'tab2-secret', link: 'http://example.com/2', timestamp: Date.now() }
      ]));
      
      await PageHelper.navigateToHome(page1);
      await PageHelper.navigateToHome(page2);
      
      // Both should handle their respective localStorage data
      const history1 = await BrowserHelper.getLocalStorageData(page1, 'secretSharerLinks');
      const history2 = await BrowserHelper.getLocalStorageData(page2, 'secretSharerLinks');
      
      expect(history1).toContain('tab1-secret');
      expect(history2).toContain('tab2-secret');
      
      await page1.close();
      await page2.close();
    });
  });
});