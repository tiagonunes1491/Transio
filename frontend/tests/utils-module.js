/* 
 * Test wrapper for utils.js
 * This file makes the utility functions available for testing with proper coverage
 */

const fs = require('fs');
const path = require('path');

// Read the original utils.js file
const utilsPath = path.join(__dirname, '..', 'static', 'utils.js');
let utilsContent = fs.readFileSync(utilsPath, 'utf8');

// Create a module-compatible version by evaluating the functions
const vm = require('vm');
const context = vm.createContext({
  // Provide browser-like globals
  document: {
    createElement: (tag) => {
      if (tag === 'div') {
        return {
          get textContent() { return this._textContent || ''; },
          set textContent(value) { 
            this._textContent = value;
            // Simulate HTML escaping - only escape < > and &
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
        textContent: '',
        innerHTML: '',
        select: () => {},
        style: { position: '', left: '', top: '', opacity: '' },
        focus: () => {},
        setSelectionRange: () => {}
      };
    },
    body: {
      appendChild: () => {},
      removeChild: () => {}
    },
    execCommand: () => true
  },
  window: global.window || {},
  navigator: global.navigator || {},
  console: console,
  alert: () => {},
  prompt: () => '',
  setTimeout: (fn, delay) => setTimeout(fn, delay),
  clearTimeout: (id) => clearTimeout(id),
  URL: global.URL || URL
});

// Execute the utils.js code in our context
vm.runInContext(utilsContent, context);

// Debug: see what's available
console.log('Available functions:', Object.keys(context).filter(key => typeof context[key] === 'function'));

// Export all the functions that were created
module.exports = {
  copyToClipboard: context.copyToClipboard,
  copyToClipboardFallback: context.copyToClipboardFallback,
  showManualCopyDialog: context.showManualCopyDialog,
  showCopySuccess: context.showCopySuccess,
  escapeHTML: context.escapeHTML,
  truncateLink: context.truncateLink,
  formatDate: context.formatDate
};