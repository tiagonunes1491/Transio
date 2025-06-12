/* utils.js - Shared utility functions for SecureSharer */

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
 * Fallback clipboard copying using the legacy execCommand method
 * @param {string} textToCopy - The text to copy to clipboard
 * @returns {boolean} - Whether the copy operation was successful
 */
function copyToClipboardFallback(textToCopy) {
    const textArea = document.createElement('textarea');
    textArea.value = textToCopy;
    
    // Make the textarea invisible but not hidden (display:none breaks copy in some browsers)
    textArea.style.position = 'fixed';
    textArea.style.top = '-9999px';
    textArea.style.left = '-9999px';
    textArea.style.width = '1px';
    textArea.style.height = '1px';
    textArea.style.opacity = '0';
    
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();
    
    let successful = false;
    try {
        successful = document.execCommand('copy');
    } catch (err) {
        console.error('Failed to copy using execCommand:', err);
    }
    
    document.body.removeChild(textArea);
    return successful;
}

/**
 * Show a manual copy dialog when automatic copying fails
 * @param {string} textToCopy - The text to copy manually
 */
function showManualCopyDialog(textToCopy) {
    // Create modal background
    const modal = document.createElement('div');
    modal.className = 'manual-copy-modal';
    modal.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.5);
        display: flex;
        justify-content: center;
        align-items: center;
        z-index: 10000;
    `;
    
    // Create modal content
    const modalContent = document.createElement('div');
    modalContent.style.cssText = `
        background: white;
        padding: 20px;
        border-radius: 8px;
        max-width: 500px;
        width: 90%;
        text-align: center;
    `;
    
    modalContent.innerHTML = `
        <h3>Copy to Clipboard</h3>
        <p>Please select and copy the text below:</p>
        <textarea readonly style="width: 100%; height: 100px; resize: none; margin: 10px 0; font-family: monospace;">${escapeHTML(textToCopy)}</textarea>
        <button style="padding: 8px 16px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer;" onclick="this.closest('.manual-copy-modal').remove()">Close</button>
    `;
    
    modal.appendChild(modalContent);
    document.body.appendChild(modal);
    
    // Auto-select the text in the textarea
    setTimeout(() => {
        const textarea = modal.querySelector('textarea');
        textarea.focus();
        textarea.select();
    }, 100);

    // Close modal when clicking outside
    modal.addEventListener('click', (e) => {
        if (e.target === modal) {
            modal.remove();
        }
    });

    // Close modal with Escape key
    const handleEscape = (e) => {
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
    const originalIcon = buttonElement.innerHTML;
    const originalBg = buttonElement.style.backgroundColor;
    
    // Add a class to disable hover effects during animation
    buttonElement.classList.add('copying');
    
    // Success color - green
    const successColor = '#10B981';
    
    // Show checkmark and change color
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
 * Escape HTML characters to prevent XSS
 * @param {string} text - The text to escape
 * @returns {string} - The escaped text
 */
function escapeHTML(text) {
    if (text == null || text === undefined) return '';
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
    if (!url || typeof url !== 'string') return '';
    if (url.length <= 60) return url;
    try {
        const urlObj = new URL(url);
        const hashContent = urlObj.hash ? urlObj.hash.substring(1) : '';
        const idPart = hashContent && hashContent.length > 20 ? 
            `#${hashContent.substring(0, 8)}...${hashContent.substring(hashContent.length - 4)}` : 
            urlObj.hash;
        return `${urlObj.protocol}//${urlObj.host}${urlObj.pathname.length > 5 ? urlObj.pathname.substring(0,5)+'...' : urlObj.pathname}${idPart}`;
    } catch (e) { 
        // Fallback for invalid URLs - truncate but show it's truncated
        return url.length > 60 ? url.substring(0, 30) + "..." + url.substring(url.length - 20) : url; 
    }
}

/**
 * Format a date string for display
 * @param {string} dateString - The ISO date string to format
 * @returns {string} - The formatted date
 */
function formatDate(dateString) {
    if (!dateString) return '';
    try {
        const date = new Date(dateString);
        if (isNaN(date.getTime())) return '';
        
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
        return date.toLocaleDateString([], { day: 'numeric', month: 'short'}) + ' ' + date.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
    } catch (error) {
        return '';
    }
}

// Export functions for testing (will be ignored in browser)
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