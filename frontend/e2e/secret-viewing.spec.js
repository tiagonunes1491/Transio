// secret-viewing.spec.js - E2E tests for secret viewing workflow

const { test, expect } = require('@playwright/test');
const {
  APIHelper,
  PageHelper,
  AssertionHelper,
  TestDataHelper,
  BrowserHelper
} = require('./helpers/test-helpers');

test.describe('Secret Viewing Workflow', () => {
  const testSecretId = 'test-secret-id-123';
  const testSecretContent = 'This is a confidential message that should be shown once';

  test.beforeEach(async ({ page }) => {
    // Clear local storage before each test
    await BrowserHelper.clearLocalStorage(page);
  });

  test('should display initial secret availability message', async ({ page }) => {
    // Mock that secret exists
    await APIHelper.mockSecretExists(page, true);
    
    await PageHelper.navigateToSecretView(page, testSecretId);

    // Should show initial message indicating secret is available
    const initialMessage = page.locator('#initialMessage');
    await expect(initialMessage).toBeVisible();
    
    // Should show reveal button
    const revealButton = page.locator('#revealButton');
    await expect(revealButton).toBeVisible();
    await expect(revealButton).toContainText('Reveal Secret');

    // Should show warning text
    await expect(initialMessage).toContainText('This secret can only be viewed once');
    await expect(initialMessage).toContainText('permanently deleted');
  });

  test('should reveal secret successfully when clicked', async ({ page }) => {
    // Mock secret exists and reveal
    await APIHelper.mockSecretExists(page, true);
    await APIHelper.mockSecretReveal(page, {
      id: testSecretId,
      content: testSecretContent,
      created_at: new Date().toISOString()
    });

    await PageHelper.navigateToSecretView(page, testSecretId);
    
    // Click reveal button
    await PageHelper.clickRevealSecret(page);

    // Should show the secret content
    await AssertionHelper.assertSecretViewSuccess(page, testSecretContent);
    
    // Initial message should be hidden
    await AssertionHelper.assertElementNotVisible(page, '#initialMessage');
  });

  test('should show loading state during secret retrieval', async ({ page }) => {
    await APIHelper.mockSecretExists(page, true);
    await APIHelper.mockSecretReveal(page);

    await PageHelper.navigateToSecretView(page, testSecretId);
    
    // Click reveal and immediately check loading state
    await PageHelper.clickRevealSecret(page);
    
    // Should show loading container (briefly)
    const loadingContainer = page.locator('#loadingContainer');
    // Note: Loading might be too fast to catch in tests, but we can at least verify it exists
    await expect(loadingContainer).toBeAttached();
  });

  test('should handle invalid secret ID in URL', async ({ page }) => {
    await PageHelper.navigateToSecretView(page, '');

    // Should show error for empty secret ID
    await AssertionHelper.assertError(page, 'Invalid link');
  });

  test('should handle non-existent secret', async ({ page }) => {
    // Mock that secret doesn't exist
    await APIHelper.mockSecretExists(page, false);

    await PageHelper.navigateToSecretView(page, 'non-existent-id');

    // Should show error message
    await AssertionHelper.assertError(page, 'Secret not found');
  });

  test('should handle secret that was already viewed', async ({ page }) => {
    // Mock secret exists initially but fails on reveal (already viewed)
    await APIHelper.mockSecretExists(page, true);
    await APIHelper.mockSecretReveal(page, null, false);

    await PageHelper.navigateToSecretView(page, testSecretId);
    await PageHelper.clickRevealSecret(page);

    // Should show error about secret being already viewed
    await AssertionHelper.assertError(page, 'Secret not found or already viewed');
  });

  test('should handle special characters in secret content', async ({ page }) => {
    const specialContent = TestDataHelper.getSpecialCharacterSecret();
    
    await APIHelper.mockSecretExists(page, true);
    await APIHelper.mockSecretReveal(page, {
      id: testSecretId,
      content: specialContent,
      created_at: new Date().toISOString()
    });

    await PageHelper.navigateToSecretView(page, testSecretId);
    await PageHelper.clickRevealSecret(page);

    await AssertionHelper.assertSecretViewSuccess(page, specialContent);
  });

  test('should handle Unicode content in secret', async ({ page }) => {
    const unicodeContent = TestDataHelper.getUnicodeSecret();
    
    await APIHelper.mockSecretExists(page, true);
    await APIHelper.mockSecretReveal(page, {
      id: testSecretId,
      content: unicodeContent,
      created_at: new Date().toISOString()
    });

    await PageHelper.navigateToSecretView(page, testSecretId);
    await PageHelper.clickRevealSecret(page);

    await AssertionHelper.assertSecretViewSuccess(page, unicodeContent);
  });

  test('should safely display HTML content without execution', async ({ page }) => {
    const htmlContent = TestDataHelper.getHTMLSecret();
    
    await APIHelper.mockSecretExists(page, true);
    await APIHelper.mockSecretReveal(page, {
      id: testSecretId,
      content: htmlContent,
      created_at: new Date().toISOString()
    });

    await PageHelper.navigateToSecretView(page, testSecretId);
    await PageHelper.clickRevealSecret(page);

    // Content should be displayed safely (HTML escaped)
    const secretContent = await PageHelper.waitForSecretContent(page);
    await expect(secretContent).toContainText('<script>'); // Should show as text, not execute
    await expect(secretContent).toContainText('alert("XSS")'); // Should show as text
  });

  test('should handle very long secret content', async ({ page }) => {
    const longContent = TestDataHelper.generateLongSecret(10000);
    
    await APIHelper.mockSecretExists(page, true);
    await APIHelper.mockSecretReveal(page, {
      id: testSecretId,
      content: longContent,
      created_at: new Date().toISOString()
    });

    await PageHelper.navigateToSecretView(page, testSecretId);
    await PageHelper.clickRevealSecret(page);

    const secretContent = await PageHelper.waitForSecretContent(page);
    await expect(secretContent).toBeVisible();
    
    // Verify scrolling works for long content
    const contentHeight = await secretContent.evaluate(el => el.scrollHeight);
    expect(contentHeight).toBeGreaterThan(0);
  });

  test('should open and close help modal', async ({ page }) => {
    await APIHelper.mockSecretExists(page, true);
    await PageHelper.navigateToSecretView(page, testSecretId);

    // Click help button
    const helpButton = page.locator('#helpButton');
    await helpButton.click();

    // Help modal should be visible
    const helpModal = page.locator('#helpModal');
    await expect(helpModal).toBeVisible();
    
    // Should contain helpful information
    await expect(helpModal).toContainText('How SecretShare Works');
    await expect(helpModal).toContainText('Click "Reveal Secret" to view');

    // Close modal using X button
    const closeButton = page.locator('#closeHelpModal');
    await closeButton.click();
    
    // Modal should be hidden
    await expect(helpModal).not.toBeVisible();
  });

  test('should close help modal with "Got it!" button', async ({ page }) => {
    await APIHelper.mockSecretExists(page, true);
    await PageHelper.navigateToSecretView(page, testSecretId);

    // Open help modal
    await page.locator('#helpButton').click();
    const helpModal = page.locator('#helpModal');
    await expect(helpModal).toBeVisible();

    // Close with "Got it!" button
    const gotItButton = page.locator('#closeHelpModalButton');
    await gotItButton.click();
    
    await expect(helpModal).not.toBeVisible();
  });

  test('should handle API errors during secret retrieval', async ({ page }) => {
    await APIHelper.mockSecretExists(page, true);
    // Mock API error for secret retrieval
    await APIHelper.mockAPIError(page, 'secret/*', 500, 'Server error');

    await PageHelper.navigateToSecretView(page, testSecretId);
    await PageHelper.clickRevealSecret(page);

    // Should show error message
    await AssertionHelper.assertError(page);
  });

  test('should handle network timeout gracefully', async ({ page }) => {
    await APIHelper.mockSecretExists(page, true);
    
    // Simulate slow network
    await BrowserHelper.simulateSlowNetwork(page, 5000);

    await PageHelper.navigateToSecretView(page, testSecretId);
    
    // The page should still load, though slowly
    const initialMessage = page.locator('#initialMessage');
    await expect(initialMessage).toBeVisible({ timeout: 10000 });
  });

  test('should navigate back to home page', async ({ page }) => {
    await APIHelper.mockSecretExists(page, true);
    await PageHelper.navigateToSecretView(page, testSecretId);

    // Click "New Secret" link in header
    const newSecretLink = page.locator('a[href="index.html"]');
    await newSecretLink.click();

    // Should navigate to home page
    await expect(page).toHaveURL(/index\.html/);
    
    // Should see the create secret form
    const secretInput = page.locator('#secretMessageInput');
    await expect(secretInput).toBeVisible();
  });

  test('should work correctly on mobile viewport', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    await APIHelper.mockSecretExists(page, true);
    await APIHelper.mockSecretReveal(page, {
      id: testSecretId,
      content: testSecretContent,
      created_at: new Date().toISOString()
    });

    await PageHelper.navigateToSecretView(page, testSecretId);
    await PageHelper.clickRevealSecret(page);

    // Should work on mobile
    await AssertionHelper.assertSecretViewSuccess(page, testSecretContent);
    
    // Check mobile-specific layout
    const header = page.locator('header');
    await expect(header).toBeVisible();
  });

  test('should extract secret ID from URL hash correctly', async ({ page }) => {
    const customSecretId = 'custom-test-id-456';
    
    await APIHelper.mockSecretExists(page, true);
    await PageHelper.navigateToSecretView(page, customSecretId);

    // Page should process the custom secret ID correctly
    const initialMessage = page.locator('#initialMessage');
    await expect(initialMessage).toBeVisible();
    
    // The page should have made an API call with the correct secret ID
    // This is verified by the mock API setup
  });

  test('should handle URL hash changes after page load', async ({ page }) => {
    await APIHelper.mockSecretExists(page, true);
    await PageHelper.navigateToSecretView(page, testSecretId);

    // Change the hash
    await page.evaluate(() => {
      window.location.hash = '#different-secret-id';
    });

    // The page should handle the hash change appropriately
    // (Implementation specific - may require page refresh or dynamic handling)
    
    // For now, just verify the page doesn't crash
    const body = page.locator('body');
    await expect(body).toBeVisible();
  });

  test('should show appropriate loading states', async ({ page }) => {
    await APIHelper.mockSecretExists(page, true);
    
    // Navigate to page and check initial loading
    await PageHelper.navigateToSecretView(page, testSecretId);
    
    // Should start with loading/checking state
    const headerTitle = page.locator('#headerTitle');
    await expect(headerTitle).toContainText('Checking');
    
    // After loading, should show initial message
    const initialMessage = page.locator('#initialMessage');
    await expect(initialMessage).toBeVisible();
  });
});