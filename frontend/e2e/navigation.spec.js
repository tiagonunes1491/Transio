// navigation.spec.js - E2E tests for navigation and UI interactions

const { test, expect } = require('@playwright/test');
const {
  APIHelper,
  PageHelper,
  AssertionHelper,
  TestDataHelper,
  BrowserHelper
} = require('./helpers/test-helpers');

test.describe('Navigation and UI Interactions', () => {
  test.beforeEach(async ({ page }) => {
    await BrowserHelper.clearLocalStorage(page);
  });

  test('should navigate between home and view pages', async ({ page }) => {
    // Start at home page
    await PageHelper.navigateToHome(page);
    
    // Verify we're on home page
    await expect(page).toHaveURL(/index\.html/);
    const secretInput = page.locator('#secretMessageInput');
    await expect(secretInput).toBeVisible();

    // Navigate to view page (simulate clicking a generated link)
    await PageHelper.navigateToSecretView(page, 'test-id');
    
    // Verify we're on view page
    await expect(page).toHaveURL(/view\.html/);
    const headerTitle = page.locator('#headerTitle');
    await expect(headerTitle).toBeVisible();

    // Navigate back to home via header link
    const newSecretLink = page.locator('a[href="index.html"]');
    await newSecretLink.click();
    
    // Should be back at home
    await expect(page).toHaveURL(/index\.html/);
    await expect(secretInput).toBeVisible();
  });

  test('should show floating create button on scroll', async ({ page }) => {
    await PageHelper.navigateToHome(page);
    
    const floatingButton = page.locator('#floatingCreateButton');
    
    // Initially should be hidden at top of page
    await expect(floatingButton).not.toBeVisible();
    
    // Scroll down to make it appear
    await page.evaluate(() => window.scrollTo(0, 1000));
    
    // Should now be visible
    await expect(floatingButton).toBeVisible();
    
    // Click should scroll back to top
    await floatingButton.click();
    
    // Should focus on input field
    const secretInput = page.locator('#secretMessageInput');
    await expect(secretInput).toBeFocused();
  });

  test('should handle responsive navigation menu', async ({ page }) => {
    // Test on mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    await PageHelper.navigateToHome(page);
    
    // Header should be visible and responsive
    const header = page.locator('header');
    await expect(header).toBeVisible();
    
    // Navigation links should be visible (may stack on mobile)
    const howItWorksLink = page.locator('a[href="#how-it-works"]');
    const whyUseLink = page.locator('a[href="#why-use"]');
    const mySecretsLink = page.locator('a[href="#mySecretsHeading"]');
    
    await expect(howItWorksLink).toBeVisible();
    await expect(whyUseLink).toBeVisible();
    await expect(mySecretsLink).toBeVisible();
  });

  test('should scroll to sections when clicking navigation links', async ({ page }) => {
    await PageHelper.navigateToHome(page);
    
    // Click "How It Works" link
    const howItWorksLink = page.locator('a[href="#how-it-works"]');
    await howItWorksLink.click();
    
    // Should scroll to how-it-works section
    const howItWorksSection = page.locator('#how-it-works');
    await expect(howItWorksSection).toBeInViewport();
    
    // Click "Why Us?" link
    const whyUseLink = page.locator('a[href="#why-use"]');
    await whyUseLink.click();
    
    // Should scroll to why-use section
    const whyUseSection = page.locator('#why-use');
    await expect(whyUseSection).toBeInViewport();
    
    // Click "My Secrets" link
    const mySecretsLink = page.locator('a[href="#mySecretsHeading"]');
    await mySecretsLink.click();
    
    // Should scroll to my secrets section
    const mySecretsSection = page.locator('#mySecretsHeading');
    await expect(mySecretsSection).toBeInViewport();
  });

  test('should handle keyboard navigation', async ({ page }) => {
    await PageHelper.navigateToHome(page);
    
    // Tab through interactive elements
    await page.keyboard.press('Tab');
    
    // Should focus on navigation links first
    let focusedElement = await page.evaluate(() => document.activeElement.tagName);
    expect(focusedElement).toBe('A');
    
    // Continue tabbing to reach the secret input
    for (let i = 0; i < 5; i++) {
      await page.keyboard.press('Tab');
    }
    
    // Should eventually reach the secret input
    const secretInput = page.locator('#secretMessageInput');
    await expect(secretInput).toBeFocused();
    
    // Tab once more to reach create button
    await page.keyboard.press('Tab');
    const createButton = page.locator('#mainCreateLinkButton');
    await expect(createButton).toBeFocused();
  });

  test('should handle form interactions with keyboard', async ({ page }) => {
    await APIHelper.mockSecretCreation(page);
    await PageHelper.navigateToHome(page);
    
    // Focus on input field
    const secretInput = page.locator('#secretMessageInput');
    await secretInput.focus();
    
    // Type a message
    await page.keyboard.type('Test message with keyboard');
    
    // Use Enter to submit (if supported)
    await page.keyboard.press('Enter');
    
    // Should either submit or tab to create button
    const createButton = page.locator('#mainCreateLinkButton');
    
    // If Enter doesn't submit, tab to button and press Enter
    if (!(await page.locator('#resultArea').isVisible())) {
      await page.keyboard.press('Tab');
      await expect(createButton).toBeFocused();
      await page.keyboard.press('Enter');
    }
    
    // Should create secret successfully
    await AssertionHelper.assertSecretCreationSuccess(page);
  });

  test('should display social media links correctly', async ({ page }) => {
    await PageHelper.navigateToHome(page);
    
    // Check footer social links
    const githubLink = page.locator('a[href*="github.com"]');
    const linkedinLink = page.locator('a[href*="linkedin.com"]');
    
    await expect(githubLink).toBeVisible();
    await expect(linkedinLink).toBeVisible();
    
    // Links should have proper attributes
    await expect(githubLink).toHaveAttribute('aria-label', 'GitHub');
    await expect(linkedinLink).toHaveAttribute('aria-label', 'LinkedIn');
  });

  test('should handle profile icon interactions', async ({ page }) => {
    await PageHelper.navigateToHome(page);
    
    // Profile icon should be visible
    const profileIcon = page.locator('.profile-icon-custom');
    await expect(profileIcon).toBeVisible();
    await expect(profileIcon).toHaveAttribute('title', 'Profile - Stay tuned!');
    
    // Should be clickable (though functionality may be placeholder)
    await expect(profileIcon).toHaveCSS('cursor', 'pointer');
  });

  test('should maintain scroll position when interacting with elements', async ({ page }) => {
    await PageHelper.navigateToHome(page);
    
    // Scroll to middle of page
    await page.evaluate(() => window.scrollTo(0, 500));
    const initialScrollY = await page.evaluate(() => window.scrollY);
    
    // Click non-navigation elements shouldn't change scroll
    const featureCard = page.locator('.feature-card-custom').first();
    await featureCard.click();
    
    const scrollYAfterClick = await page.evaluate(() => window.scrollY);
    expect(Math.abs(scrollYAfterClick - initialScrollY)).toBeLessThan(50);
  });

  test('should handle window resize gracefully', async ({ page }) => {
    await PageHelper.navigateToHome(page);
    
    // Start with desktop size
    await page.setViewportSize({ width: 1200, height: 800 });
    
    // Verify desktop layout
    const header = page.locator('header');
    await expect(header).toBeVisible();
    
    // Resize to mobile
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Layout should adapt
    await expect(header).toBeVisible();
    const secretInput = page.locator('#secretMessageInput');
    await expect(secretInput).toBeVisible();
    
    // Resize to tablet
    await page.setViewportSize({ width: 768, height: 1024 });
    
    // Should still work
    await expect(secretInput).toBeVisible();
  });

  test('should handle focus management correctly', async ({ page }) => {
    await PageHelper.navigateToHome(page);
    
    // Click on input should focus it
    const secretInput = page.locator('#secretMessageInput');
    await secretInput.click();
    await expect(secretInput).toBeFocused();
    
    // Click outside should blur it
    const body = page.locator('body');
    await body.click({ position: { x: 10, y: 10 } });
    await expect(secretInput).not.toBeFocused();
    
    // Using tab should focus it again
    await page.keyboard.press('Tab');
    // May need multiple tabs depending on page structure
    for (let i = 0; i < 10; i++) {
      const focused = await secretInput.evaluate(el => document.activeElement === el);
      if (focused) break;
      await page.keyboard.press('Tab');
    }
  });

  test('should handle empty states correctly', async ({ page }) => {
    await PageHelper.navigateToHome(page);
    
    // Initially should show "no secrets" state
    const noSecretsSection = page.locator('#noSecretsSection');
    await expect(noSecretsSection).toBeVisible();
    
    // History section should be hidden
    const historySection = page.locator('#historySection');
    await expect(historySection).not.toBeVisible();
    
    // "Create a Secure Note" button should be visible
    const createButton = page.locator('#noSecretsCreateButton');
    await expect(createButton).toBeVisible();
  });

  test('should show history when secrets exist in localStorage', async ({ page }) => {
    // Pre-populate localStorage with secret history
    const mockHistory = [
      {
        id: 'test-id-1',
        link: 'http://127.0.0.1:3000/view.html#test-id-1',
        timestamp: Date.now() - 86400000, // 1 day ago
        viewed: false
      },
      {
        id: 'test-id-2', 
        link: 'http://127.0.0.1:3000/view.html#test-id-2',
        timestamp: Date.now() - 3600000, // 1 hour ago
        viewed: true
      }
    ];
    
    await BrowserHelper.setLocalStorageData(page, 'secretSharerLinks', JSON.stringify(mockHistory));
    
    await PageHelper.navigateToHome(page);
    
    // Should show history section instead of empty state
    const historySection = page.locator('#historySection');
    await expect(historySection).toBeVisible();
    
    // No secrets section should be hidden
    const noSecretsSection = page.locator('#noSecretsSection');
    await expect(noSecretsSection).not.toBeVisible();
    
    // Should show history items
    const linksHistory = page.locator('#linksHistory');
    await expect(linksHistory).toBeVisible();
  });

  test('should handle page loading states', async ({ page }) => {
    // Navigate and check that page loads completely
    await PageHelper.navigateToHome(page);
    
    // Wait for all critical elements to be visible
    const secretInput = page.locator('#secretMessageInput');
    const createButton = page.locator('#mainCreateLinkButton');
    const header = page.locator('header');
    const footer = page.locator('footer');
    
    await expect(secretInput).toBeVisible();
    await expect(createButton).toBeVisible();
    await expect(header).toBeVisible();
    await expect(footer).toBeVisible();
    
    // Check that CSS is loaded (elements have proper styling)
    const backgroundColor = await page.evaluate(() => 
      getComputedStyle(document.body).backgroundColor
    );
    expect(backgroundColor).not.toBe('rgba(0, 0, 0, 0)'); // Not transparent
  });

  test('should handle browser back/forward navigation', async ({ page }) => {
    // Start at home
    await PageHelper.navigateToHome(page);
    await expect(page).toHaveURL(/index\.html/);
    
    // Navigate to view page
    await PageHelper.navigateToSecretView(page, 'test-id');
    await expect(page).toHaveURL(/view\.html/);
    
    // Go back
    await page.goBack();
    await expect(page).toHaveURL(/index\.html/);
    
    // Go forward
    await page.goForward();
    await expect(page).toHaveURL(/view\.html/);
    
    // Page should still function correctly
    const headerTitle = page.locator('#headerTitle');
    await expect(headerTitle).toBeVisible();
  });
});