// secret-creation.spec.js - E2E tests for secret creation workflow

const { test, expect } = require('@playwright/test');
const {
  APIHelper,
  PageHelper,
  AssertionHelper,
  TestDataHelper,
  BrowserHelper
} = require('./helpers/test-helpers');

test.describe('Secret Creation Workflow', () => {
  test.beforeEach(async ({ page }) => {
    // Clear local storage before each test
    await BrowserHelper.clearLocalStorage(page);
  });

  test('should create a secret successfully with valid input', async ({ page }) => {
    // Mock the API response for secret creation
    await APIHelper.mockSecretCreation(page);

    // Navigate to home page
    await PageHelper.navigateToHome(page);

    // Fill in a secret message
    const testMessage = 'This is my secret message for testing';
    await PageHelper.fillSecretMessage(page, testMessage);

    // Click create link button
    await PageHelper.clickCreateLink(page);

    // Assert successful creation
    const generatedLink = await AssertionHelper.assertSecretCreationSuccess(page);
    
    // Verify link format
    expect(generatedLink).toContain('view.html#test-secret-id-123');
    expect(generatedLink).toMatch(/^http:\/\/127\.0\.0\.1:3000\/view\.html#.+/);
  });

  test('should handle form validation for empty input', async ({ page }) => {
    await PageHelper.navigateToHome(page);

    // Try to create secret with empty input
    await AssertionHelper.assertFormValidation(
      page,
      '#secretMessageInput',
      '#mainCreateLinkButton'
    );

    // Verify result area is not shown
    await AssertionHelper.assertElementNotVisible(page, '#resultArea');
  });

  test('should copy link to clipboard successfully', async ({ page }) => {
    // Enable clipboard access
    await BrowserHelper.enableClipboardAccess(page);
    
    // Mock API response
    await APIHelper.mockSecretCreation(page);

    await PageHelper.navigateToHome(page);
    
    // Create a secret
    await PageHelper.fillSecretMessage(page, 'Test secret for clipboard');
    await PageHelper.clickCreateLink(page);
    
    // Wait for result and copy link
    await PageHelper.waitForResultArea(page);
    await PageHelper.clickCopyLink(page);
    
    // Verify clipboard content
    const clipboardContent = await PageHelper.getClipboardContent(page);
    expect(clipboardContent).toContain('view.html#test-secret-id-123');
  });

  test('should handle special characters in secret message', async ({ page }) => {
    await APIHelper.mockSecretCreation(page);
    await PageHelper.navigateToHome(page);

    // Test with special characters
    const specialMessage = TestDataHelper.getSpecialCharacterSecret();
    await PageHelper.fillSecretMessage(page, specialMessage);
    await PageHelper.clickCreateLink(page);

    await AssertionHelper.assertSecretCreationSuccess(page);
  });

  test('should handle Unicode characters in secret message', async ({ page }) => {
    await APIHelper.mockSecretCreation(page);
    await PageHelper.navigateToHome(page);

    // Test with Unicode characters
    const unicodeMessage = TestDataHelper.getUnicodeSecret();
    await PageHelper.fillSecretMessage(page, unicodeMessage);
    await PageHelper.clickCreateLink(page);

    await AssertionHelper.assertSecretCreationSuccess(page);
  });

  test('should handle HTML content in secret message', async ({ page }) => {
    await APIHelper.mockSecretCreation(page);
    await PageHelper.navigateToHome(page);

    // Test with HTML content
    const htmlMessage = TestDataHelper.getHTMLSecret();
    await PageHelper.fillSecretMessage(page, htmlMessage);
    await PageHelper.clickCreateLink(page);

    await AssertionHelper.assertSecretCreationSuccess(page);
  });

  test('should handle very long secret messages', async ({ page }) => {
    await APIHelper.mockSecretCreation(page);
    await PageHelper.navigateToHome(page);

    // Test with long message
    const longMessage = TestDataHelper.generateLongSecret(5000);
    await PageHelper.fillSecretMessage(page, longMessage);
    await PageHelper.clickCreateLink(page);

    await AssertionHelper.assertSecretCreationSuccess(page);
  });

  test('should show loading state during secret creation', async ({ page }) => {
    // Mock API with delay to see loading state
    await APIHelper.mockSecretCreation(page);
    
    await PageHelper.navigateToHome(page);
    await PageHelper.fillSecretMessage(page, 'Test message');
    
    // Click create button and immediately check loading state
    const button = await PageHelper.clickCreateLink(page);
    
    // Verify button shows loading text
    await expect(button).toContainText('Encrypting & Creating...');
    await expect(button).toBeDisabled();
    
    // Wait for completion
    await PageHelper.waitForResultArea(page);
  });

  test('should handle API error during secret creation', async ({ page }) => {
    // Mock API error
    await APIHelper.mockAPIError(page, 'share', 500, 'Server error during secret creation');
    
    await PageHelper.navigateToHome(page);
    await PageHelper.fillSecretMessage(page, 'Test message');
    await PageHelper.clickCreateLink(page);
    
    // Should show some error indication (this depends on implementation)
    // For now, we'll check that result area doesn't appear
    await new Promise(resolve => setTimeout(resolve, 1000)); // Wait a bit
    await AssertionHelper.assertElementNotVisible(page, '#resultArea');
  });

  test('should work with "Create a Secure Note" button from empty state', async ({ page }) => {
    await APIHelper.mockSecretCreation(page);
    await PageHelper.navigateToHome(page);

    // Click the "Create a Secure Note" button in the empty state
    const noSecretsButton = page.locator('#noSecretsCreateButton');
    await expect(noSecretsButton).toBeVisible();
    await noSecretsButton.click();

    // Should scroll to create section (check if input is focused)
    const input = page.locator('#secretMessageInput');
    await expect(input).toBeFocused();
  });

  test('should work with floating create button', async ({ page }) => {
    await PageHelper.navigateToHome(page);

    // Scroll down to make floating button visible
    await page.evaluate(() => window.scrollTo(0, 1000));
    
    // Wait for floating button to appear
    const floatingButton = page.locator('#floatingCreateButton');
    await expect(floatingButton).toBeVisible();
    
    await floatingButton.click();
    
    // Should scroll back to create section
    const input = page.locator('#secretMessageInput');
    await expect(input).toBeFocused();
  });

  test('should maintain secret history in localStorage', async ({ page }) => {
    await APIHelper.mockSecretCreation(page);
    await PageHelper.navigateToHome(page);

    // Create a secret
    await PageHelper.fillSecretMessage(page, 'Test secret for history');
    await PageHelper.clickCreateLink(page);
    await PageHelper.waitForResultArea(page);

    // Check that history was saved to localStorage
    const historyData = await BrowserHelper.getLocalStorageData(page, 'secretSharerLinks');
    expect(historyData).toBeTruthy();
    
    const history = JSON.parse(historyData);
    expect(Array.isArray(history)).toBe(true);
    expect(history.length).toBeGreaterThan(0);
    expect(history[0]).toHaveProperty('id');
    expect(history[0]).toHaveProperty('link');
  });

  test('should clear input after successful secret creation', async ({ page }) => {
    await APIHelper.mockSecretCreation(page);
    await PageHelper.navigateToHome(page);

    const testMessage = 'Message that should be cleared';
    const input = await PageHelper.fillSecretMessage(page, testMessage);
    
    await PageHelper.clickCreateLink(page);
    await PageHelper.waitForResultArea(page);

    // Input should be cleared after successful creation
    await expect(input).toHaveValue('');
  });

  test('should display secret link in read-only input field', async ({ page }) => {
    await APIHelper.mockSecretCreation(page);
    await PageHelper.navigateToHome(page);

    await PageHelper.fillSecretMessage(page, 'Test message');
    await PageHelper.clickCreateLink(page);

    const linkInput = page.locator('#secretLinkInput');
    await expect(linkInput).toBeVisible();
    await expect(linkInput).toHaveAttribute('readonly');
    
    const linkValue = await linkInput.inputValue();
    expect(linkValue).toContain('view.html#test-secret-id-123');
  });

  test('should work correctly on mobile viewport', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    await APIHelper.mockSecretCreation(page);
    await PageHelper.navigateToHome(page);

    // Test mobile-specific functionality
    await PageHelper.fillSecretMessage(page, 'Mobile test message');
    await PageHelper.clickCreateLink(page);

    await AssertionHelper.assertSecretCreationSuccess(page);

    // Verify responsive design elements
    const createSection = page.locator('#createSection');
    await expect(createSection).toBeVisible();
  });
});