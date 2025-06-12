// test-helpers.js - Shared utilities for E2E tests

const { expect } = require('@playwright/test');

/**
 * Mock API responses for testing
 */
class APIHelper {
  static async mockSecretCreation(page, response = null) {
    const defaultResponse = {
      id: 'test-secret-id-123',
      link: 'http://127.0.0.1:3000/view.html#test-secret-id-123',
      message: 'Secret created successfully'
    };

    await page.route('**/share', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(response || defaultResponse)
      });
    });
  }

  static async mockSecretExists(page, exists = true) {
    await page.route('**/secret/*/exists', async (route) => {
      await route.fulfill({
        status: exists ? 200 : 404,
        contentType: 'application/json',
        body: JSON.stringify({
          exists,
          message: exists ? 'Secret exists' : 'Secret not found'
        })
      });
    });
  }

  static async mockSecretReveal(page, secret = null, shouldDelete = true) {
    const defaultSecret = {
      id: 'test-secret-id-123',
      content: 'This is a test secret message',
      created_at: new Date().toISOString()
    };

    await page.route('**/secret/*', async (route) => {
      if (route.request().method() === 'GET') {
        await route.fulfill({
          status: shouldDelete ? 200 : 404,
          contentType: 'application/json',
          body: JSON.stringify({
            success: shouldDelete,
            secret: shouldDelete ? (secret || defaultSecret) : null,
            message: shouldDelete ? 'Secret retrieved successfully' : 'Secret not found or already viewed'
          })
        });
      }
    });
  }

  static async mockAPIError(page, endpoint, statusCode = 500, message = 'Internal server error') {
    await page.route(`**/${endpoint}`, async (route) => {
      await route.fulfill({
        status: statusCode,
        contentType: 'application/json',
        body: JSON.stringify({
          error: true,
          message
        })
      });
    });
  }
}

/**
 * Page interaction helpers
 */
class PageHelper {
  static async navigateToHome(page) {
    await page.goto('/index.html');
    await page.waitForLoadState('networkidle');
  }

  static async navigateToSecretView(page, secretId = 'test-secret-id-123') {
    await page.goto(`/view.html#${secretId}`);
    await page.waitForLoadState('networkidle');
  }

  static async fillSecretMessage(page, message) {
    const input = page.locator('#secretMessageInput');
    await input.fill(message);
    return input;
  }

  static async clickCreateLink(page) {
    const button = page.locator('#mainCreateLinkButton');
    await button.click();
    return button;
  }

  static async clickRevealSecret(page) {
    const button = page.locator('#revealButton');
    await button.click();
    return button;
  }

  static async getGeneratedLink(page) {
    const linkInput = page.locator('#secretLinkInput');
    await expect(linkInput).toBeVisible();
    return await linkInput.inputValue();
  }

  static async clickCopyLink(page) {
    // Grant clipboard permissions
    await page.context().grantPermissions(['clipboard-read', 'clipboard-write']);
    
    const copyButton = page.locator('#copyLinkButton');
    await copyButton.click();
    return copyButton;
  }

  static async getClipboardContent(page) {
    return await page.evaluate(() => navigator.clipboard.readText());
  }

  static async waitForResultArea(page) {
    const resultArea = page.locator('#resultArea');
    await expect(resultArea).toBeVisible();
    return resultArea;
  }

  static async waitForSecretContent(page) {
    const secretContent = page.locator('#secretContent');
    await expect(secretContent).toBeVisible();
    return secretContent;
  }

  static async waitForErrorContent(page) {
    const errorContent = page.locator('#errorContent');
    await expect(errorContent).toBeVisible();
    return errorContent;
  }
}

/**
 * Assertion helpers
 */
class AssertionHelper {
  static async assertSecretCreationSuccess(page, expectedMessage) {
    // Check that result area is visible
    await PageHelper.waitForResultArea(page);
    
    // Check that link was generated
    const link = await PageHelper.getGeneratedLink(page);
    expect(link).toContain('/view.html#');
    expect(link).toMatch(/view\.html#[a-zA-Z0-9-]+/);
    
    // Check that copy button is present
    const copyButton = page.locator('#copyLinkButton');
    await expect(copyButton).toBeVisible();
    
    return link;
  }

  static async assertSecretViewSuccess(page, expectedContent) {
    // Check that secret content area is visible
    const secretContent = await PageHelper.waitForSecretContent(page);
    
    // Check that the secret content matches expectation
    if (expectedContent) {
      await expect(secretContent).toContainText(expectedContent);
    }
    
    return secretContent;
  }

  static async assertError(page, expectedErrorMessage = null) {
    // Check that error content area is visible
    const errorContent = await PageHelper.waitForErrorContent(page);
    
    // Check error message if provided
    if (expectedErrorMessage) {
      await expect(errorContent).toContainText(expectedErrorMessage);
    }
    
    return errorContent;
  }

  static async assertElementNotVisible(page, selector) {
    const element = page.locator(selector);
    await expect(element).not.toBeVisible();
  }

  static async assertElementVisible(page, selector) {
    const element = page.locator(selector);
    await expect(element).toBeVisible();
  }

  static async assertFormValidation(page, inputSelector, buttonSelector) {
    // Test empty input validation
    const input = page.locator(inputSelector);
    const button = page.locator(buttonSelector);
    
    await input.fill('');
    await button.click();
    
    // Should focus back to input for validation
    await expect(input).toBeFocused();
  }
}

/**
 * Test data generators
 */
class TestDataHelper {
  static generateRandomSecret(length = 50) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 !@#$%^&*()';
    let result = '';
    for (let i = 0; i < length; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }

  static generateLongSecret(length = 1000) {
    return this.generateRandomSecret(length);
  }

  static getSpecialCharacterSecret() {
    return 'Special chars: <>&"\'`\n\r\t{}[]()';
  }

  static getUnicodeSecret() {
    return '🔒 Unicode test: αβγδ ñáéíóú 中文 العربية 日本語';
  }

  static getHTMLSecret() {
    return '<script>alert("XSS")</script><b>Bold</b> & normal text';
  }
}

/**
 * Browser specific helpers
 */
class BrowserHelper {
  static async enableClipboardAccess(page) {
    await page.context().grantPermissions(['clipboard-read', 'clipboard-write']);
  }

  static async disableNetworkAccess(page) {
    await page.route('**/*', route => route.abort());
  }

  static async simulateSlowNetwork(page, delay = 1000) {
    await page.route('**/*', async route => {
      await new Promise(resolve => setTimeout(resolve, delay));
      await route.continue();
    });
  }

  static async getLocalStorageData(page, key) {
    return await page.evaluate((key) => {
      return localStorage.getItem(key);
    }, key);
  }

  static async setLocalStorageData(page, key, value) {
    await page.evaluate(({ key, value }) => {
      localStorage.setItem(key, value);
    }, { key, value });
  }

  static async clearLocalStorage(page) {
    await page.evaluate(() => {
      localStorage.clear();
    });
  }
}

module.exports = {
  APIHelper,
  PageHelper,
  AssertionHelper,
  TestDataHelper,
  BrowserHelper
};