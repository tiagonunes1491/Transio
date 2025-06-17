/* utils.js - Testable version for coverage */

/**
 * Copy text to clipboard with visual feedback and fallbacks for HTTP environments
 * @param {string} textToCopy - The text to copy to clipboard
 * @param {HTMLElement} buttonElement - The button element that triggered the copy action
 */
async function copyToClipboard(textToCopy, buttonElement) {
  try {
    // First try the modern Clipboard API (HTTPS/localhost only)
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(textToCopy);
      showCopySuccess(buttonElement);
      return;
    }

    // Fallback: Use the legacy document.execCommand method
    if (copyToClipboardFallback(textToCopy)) {
      showCopySuccess(buttonElement);
      return;
    }

    // Last resort: Show the text for manual copying
    showManualCopyDialog(textToCopy);
  } catch (error) {
    console.error('Failed to copy to clipboard:', error);
    showManualCopyDialog(textToCopy);
  }
}

/**
 * Legacy fallback method using document.execCommand
 * @param {string} text - The text to copy
 * @returns {boolean} - True if successful, false otherwise
 */
function copyToClipboardFallback(text) {
  try {
    // Create a temporary textarea element
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    textarea.style.left = '-9999px';
    textarea.style.pointerEvents = 'none';

    document.body.appendChild(textarea);
    textarea.focus();
    textarea.select();
    textarea.setSelectionRange(0, text.length);

    // Try to copy using the legacy method
    const successful = document.execCommand('copy');
    document.body.removeChild(textarea);

    return successful;
  } catch (error) {
    console.error('Fallback copy failed:', error);
    return false;
  }
}

/**
 * Show manual copy dialog when clipboard APIs fail
 * @param {string} text - The text to display for manual copying
 */
function showManualCopyDialog(text) {
  prompt(
    'Auto-copy to clipboard is not available. Please manually copy this text:\n\n' +
        '(The text is pre-selected for you)',
    text
  );
}

/**
 * Show copy success visual feedback
 * @param {HTMLElement} buttonElement - The button element to update
 */
function showCopySuccess(buttonElement) {
  if (!buttonElement) return;

  const originalIcon = buttonElement.innerHTML;
  // Use a sophisticated green that aligns with the template's color palette
  const successColor = '#2d7d6e'; // Sophisticated teal-green success color
  const originalBg = buttonElement.style.backgroundColor;

  // Add class to prevent hover effects during animation
  buttonElement.classList.add('copying');
  buttonElement.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 256 256"><path d="M229.66,77.66l-128,128a8,8,0,0,1-11.32,0l-56-56a8,8,0,0,1,11.32-11.32L96,188.69,218.34,66.34a8,8,0,0,1,11.32,11.32Z"></path></svg>';
  buttonElement.style.backgroundColor = successColor;

  setTimeout(() => {
    buttonElement.innerHTML = originalIcon;
    if (originalBg) buttonElement.style.backgroundColor = originalBg;
    else buttonElement.style.removeProperty('background-color');
    // Remove class to restore hover effects
    buttonElement.classList.remove('copying');
  }, 2000);
}

/**
 * Escape HTML characters to prevent XSS attacks
 * @param {string} text - The text to escape
 * @returns {string} - The escaped text
 */
function escapeHTML(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

/**
 * Truncate a URL for display purposes
 * @param {string} url - The URL to truncate
 * @returns {string} - The truncated URL
 */
function truncateLink(url) {
  if (url.length <= 60) return url;
  try {
    const urlObj = new URL(url);
    const hashContent = urlObj.hash ? urlObj.hash.substring(1) : '';
    const idPart = hashContent ? `#${hashContent.substring(0, 8)}...${hashContent.substring(hashContent.length - 4)}` : '';
    return `${urlObj.protocol}//${urlObj.host}${(urlObj.pathname.length > 5 ? urlObj.pathname.substring(0, 5) + '...' : urlObj.pathname)}${idPart}`;
  } catch (e) {
    return url.substring(0, 30) + '...' + url.substring(url.length - 20);
  }
}

/**
 * Format a date string for display
 * @param {string} dateString - The date string to format
 * @returns {string} - The formatted date string
 */
function formatDate(dateString) {
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now - date;
  const diffSecs = Math.floor(diffMs / 1000);
  if (diffSecs < 60) return 'Just now';
  const diffMins = Math.floor(diffSecs / 60);
  if (diffMins < 60) return `${diffMins} min${diffMins === 1 ? '' : 's'} ago`;
  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours} hr${diffHours === 1 ? '' : 's'} ago`;
  const diffDays = Math.floor(diffHours / 24);
  if (diffDays < 7) return `${diffDays} day${diffDays === 1 ? '' : 's'} ago`;
  return date.toLocaleDateString([], { day: 'numeric', month: 'short' }) + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

// Export for Node.js testing environment
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    copyToClipboard,
    copyToClipboardFallback,
    showManualCopyDialog,
    showCopySuccess,
    escapeHTML,
    truncateLink,
    formatDate
  };
}
