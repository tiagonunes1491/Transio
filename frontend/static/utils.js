/* utils.js - Shared utility functions for SecureSharer */
/* exported copyToClipboard, truncateLink, formatDate, copyToClipboardFallback, showManualCopyDialog, showCopySuccess, escapeHTML */

/**
 * Copy text to clipboard with visual feedback and fallbacks for HTTP environments
 * @param {string} textToCopy - The text to copy to clipboard
 * @param {HTMLElement} buttonElement - The button element that triggered the copy action
 */
// eslint-disable-next-line no-unused-vars
async function copyToClipboard(textToCopy, buttonElement) {
  try {
    // First try the modern Clipboard API (HTTPS/localhost only)
    // Test commit to review if CI PR works
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
    // Failed to copy to clipboard, fallback to manual copy
    showManualCopyDialog(textToCopy);
  }
}

/**
 * Fallback clipboard copy using document.execCommand (works on HTTP)
 * @param {string} text - The text to copy
 * @returns {boolean} - Whether the copy was successful
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
    // Fallback copy failed
    return false;
  }
}

/**
 * Show manual copy dialog when clipboard APIs fail
 * @param {string} text - The text to display for manual copying
 */
function showManualCopyDialog(text) {
  // Remove any existing modal
  const existingModal = document.querySelector('.manual-copy-modal');
  if (existingModal) {
    existingModal.remove();
  }

  // Create a modal for manual copying
  const modal = document.createElement('div');
  modal.className = 'manual-copy-modal';
  modal.innerHTML = `
        <div style="position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 9999; display: flex; justify-content: center; align-items: center; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;">
            <div style="background: white; padding: 24px; border-radius: 12px; max-width: 500px; width: 90%; box-shadow: 0 10px 25px rgba(0,0,0,0.2);">
                <h3 style="margin: 0 0 16px 0; color: #2d3748; font-size: 18px; font-weight: 600;">Copy to Clipboard</h3>
                <p style="margin: 0 0 16px 0; color: #4a5568; font-size: 14px;">Please manually copy the text below:</p>
                <textarea readonly style="width: 100%; height: 120px; margin: 0 0 16px 0; padding: 12px; border: 1px solid #e2e8f0; border-radius: 6px; font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; font-size: 12px; resize: none; background: #f7fafc;" onclick="this.select()">${escapeHTML(text)}</textarea>
                <div style="display: flex; justify-content: flex-end; gap: 8px;">
                    <button onclick="this.closest('.manual-copy-modal').remove()" style="padding: 8px 16px; background: #e2e8f0; color: #4a5568; border: none; border-radius: 6px; cursor: pointer; font-size: 14px; font-weight: 500;">Close</button>
                </div>
            </div>
        </div>
    `;

  document.body.appendChild(modal);

  // Auto-select the text in the textarea
  setTimeout(() => {
    const textarea = modal.querySelector('textarea');
    textarea.focus();
    textarea.select();
  }, 100);

  // Close modal when clicking outside
  modal.addEventListener('click', e => {
    if (e.target === modal) {
      modal.remove();
    }
  });

  // Close modal with Escape key
  const handleEscape = e => {
    if (e.key === 'Escape') {
      modal.remove();
      document.removeEventListener('keydown', handleEscape);
    }
  };
  document.addEventListener('keydown', handleEscape);
}

/**
 * Show visual feedback for successful copy operation
 * @param {HTMLElement} buttonElement - The button element to show feedback on
 */
function showCopySuccess(buttonElement) {
  if (!buttonElement) return;

  const originalIcon = buttonElement.innerHTML;
  // Use a sophisticated green that aligns with the template's color palette
  const successColor = '#2d7d6e'; // Sophisticated teal-green success color
  const originalBg = buttonElement.style.backgroundColor;

  // Add class to prevent hover effects during animation
  buttonElement.classList.add('copying');
  buttonElement.innerHTML =
    '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 256 256"><path d="M229.66,77.66l-128,128a8,8,0,0,1-11.32,0l-56-56a8,8,0,0,1,11.32-11.32L96,188.69,218.34,66.34a8,8,0,0,1,11.32,11.32Z"></path></svg>';
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
 * Escape HTML characters to prevent XSS
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
// eslint-disable-next-line no-unused-vars
function truncateLink(url) {
  if (url.length <= 60) return url;
  try {
    const urlObj = new URL(url);
    const hashContent = urlObj.hash ? urlObj.hash.substring(1) : '';
    const idPart = hashContent
      ? `#${hashContent.substring(0, 8)}...${hashContent.substring(hashContent.length - 4)}`
      : '';
    return `${urlObj.protocol}//${urlObj.host}${urlObj.pathname.length > 5 ? urlObj.pathname.substring(0, 5) + '...' : urlObj.pathname}${idPart}`;
  } catch (e) {
    return url.substring(0, 30) + '...' + url.substring(url.length - 20);
  }
}

/**
 * Format a date string for display
 * @param {string} dateString - The date string to format
 * @returns {string} - The formatted date string
 */
// eslint-disable-next-line no-unused-vars
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
  return (
    date.toLocaleDateString([], { day: 'numeric', month: 'short' }) +
    ' ' +
    date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  );
}
