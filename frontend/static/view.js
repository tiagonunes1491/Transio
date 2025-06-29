/* view.js - JavaScript specific to view.html */
/* global escapeHTML */

document.addEventListener('DOMContentLoaded', () => {
  // Extract the link ID from the URL hash
  const hash = window.location.hash.substring(1); // Remove the # character
  // Handle URL format: #secretId&p=passphrase or just #secretId
  const linkId = hash.includes('&') ? hash.split('&')[0] : hash;

  // Get DOM elements
  const headerTitle = document.getElementById('headerTitle');
  const initialMessage = document.getElementById('initialMessage');
  const loadingContainer = document.getElementById('loadingContainer');
  const secretContent = document.getElementById('secretContent');
  const errorContent = document.getElementById('errorContent');
  const passphraseInput = document.getElementById('passphraseInput');
  const revealButton = document.getElementById('revealButton');
  const togglePassphraseVisibility = document.getElementById('togglePassphraseVisibility');

  // Help modal elements
  const helpButton = document.getElementById('helpButton');
  const helpModal = document.getElementById('helpModal');
  const closeHelpModal = document.getElementById('closeHelpModal');
  const closeHelpModalButton = document.getElementById('closeHelpModalButton');

  // Function to reset all UI states
  function resetUI() {
    initialMessage.classList.add('hidden');
    loadingContainer.classList.add('hidden');
    secretContent.classList.add('hidden');
    errorContent.classList.add('hidden');
  }

  if (!linkId) {
    showError('Can\'t unlock - link may be expired or needs the correct pass-phrase.');
    return;
  }

  // **SECURE FLOW: No backend probing on page load**
  // Always show the initial message with passphrase input and reveal button
  headerTitle.textContent = 'Secret Viewer';
  initialMessage.classList.remove('hidden');

  // Setup passphrase visibility toggle
  if (togglePassphraseVisibility) {
    togglePassphraseVisibility.addEventListener('click', () => {
      const eyeIcon = document.getElementById('eyeIcon');
      const eyeSlashIcon = document.getElementById('eyeSlashIcon');
      
      if (passphraseInput.type === 'password') {
        passphraseInput.type = 'text';
        eyeIcon.classList.add('hidden');
        eyeSlashIcon.classList.remove('hidden');
      } else {
        passphraseInput.type = 'password';
        eyeIcon.classList.remove('hidden');
        eyeSlashIcon.classList.add('hidden');
      }
    });
  }

  // Setup reveal button click handler
  if (revealButton) {
    revealButton.addEventListener('click', async () => {
      resetUI();
      loadingContainer.classList.remove('hidden');
      headerTitle.textContent = 'Loading...';

      await fetchSecret(linkId);
    });
  }

  // Auto-populate passphrase from URL fragment if present
  const urlFragment = window.location.hash;
  if (urlFragment && urlFragment.includes('p=')) {
    try {
      const fragmentParts = urlFragment.substring(1).split('&');
      for (const part of fragmentParts) {
        if (part.startsWith('p=')) {
          const passphrase = decodeURIComponent(part.split('=')[1]);
          if (passphraseInput) {
            passphraseInput.value = passphrase;
          }
          break;
        }
      }
    } catch (error) {
      console.log('Could not parse passphrase from URL fragment');
    }
  }

  // Encryption/Decryption helper functions (same as in test-secure-flow.html)
  
  // URL-safe base64 encoding
  const b64u = bytes =>
    btoa(String.fromCharCode(...bytes))
      .replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');

  // URL-safe base64 decoding  
  const b64uDecode = str => {
    const padding = '='.repeat((4 - str.length % 4) % 4);
    const base64 = str.replace(/-/g, '+').replace(/_/g, '/') + padding;
    const binary = atob(base64);
    return new Uint8Array(binary.split('').map(char => char.charCodeAt(0)));
  };

  // Main decryption helper
  async function unseal(encryptedData, passPhrase) {
    try {
      // (1) Decode base64 components
      const salt = b64uDecode(encryptedData.salt);
      const nonce = b64uDecode(encryptedData.nonce);
      const ct = b64uDecode(encryptedData.ct);

      // Load Argon2 if needed
      if (typeof argon2 === 'undefined') {
        await loadArgon2();
      }

      // (2) Derive key using same Argon2id parameters
      const { hash: key } = await argon2.hash({
        pass: passPhrase,
        salt,
        hashLen: 32,
        time: 2,
        mem: 1 << 16,
        parallelism: 1,
        type: argon2.ArgonType.Argon2id
      });

      // (3) Import key for decryption
      const subtleKey = await crypto.subtle.importKey(
        'raw', key, 'AES-GCM', false, ['decrypt']
      );

      // (4) Decrypt
      const plaintextBuf = await crypto.subtle.decrypt(
        { name: 'AES-GCM', iv: nonce },
        subtleKey,
        ct
      );

      // (5) Return decoded text
      return new TextDecoder().decode(plaintextBuf);
    } catch (error) {
      console.error('Decryption failed:', error);
      throw new Error(`Decryption failed: ${error.message}`);
    }
  }

  // Function to dynamically load Argon2 library if needed
  async function loadArgon2() {
    if (typeof argon2 !== 'undefined') {
      return; // Already loaded
    }

    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/argon2-browser@1.18.0/dist/argon2-bundled.min.js';
      script.onload = () => resolve();
      script.onerror = () => reject(new Error('Failed to load Argon2 library'));
      document.head.appendChild(script);
    });
  }
  // Function to fetch the secret from the API
  async function fetchSecret(linkId) {
    try {
      // Determine API endpoint based on environment
      const isDevelopment =
        window.location.hostname === 'localhost' ||
        window.location.hostname === '127.0.0.1' ||
        window.location.protocol === 'file:';
      const apiEndpoint = isDevelopment
        ? `http://127.0.0.1:5000/api/share/secret/${linkId}` // Local dev
        : `/api/share/secret/${linkId}`; // Deployed

      // Fetch the secret
      const response = await fetch(apiEndpoint, {
        headers: {
          Accept: 'application/json'
        }
      });

      // Always hide loading state
      resetUI();

      // Backend now always returns 200, check if response is ok
      if (!response.ok) {
        showError('Can\'t unlock - link may be expired or needs the correct pass-phrase.');
        return;
      }

      try {
        // Handle successful response
        const data = await response.json();

        // Check if we got an empty object (should not happen with new backend)
        if (!data || Object.keys(data).length === 0) {
          showRetryPassphrase('Unable to decrypt. Please check your passphrase and try again.');
          return;
        }

        if (data.error) {
          showRetryPassphrase('Unable to decrypt. Please check your passphrase and try again.');
        } else if (data.e2ee) {
          // New backend format - E2EE data
          await processE2EESecret(data);
        } else if (data.payload) {
          // New backend format - traditional secret
          await processTraditionalSecret(data.payload, data.mime);
        } else if (data.secret) {
          // Legacy format support
          await processSecret(data.secret);
        } else {
          showRetryPassphrase('Unable to decrypt. Please check your passphrase and try again.');
        }
      } catch (jsonParseError) {
        showRetryPassphrase('Unable to decrypt. Please check your passphrase and try again.');
      }
    } catch (error) {
      resetUI();
      showRetryPassphrase('Connection error. Please check your passphrase and try again.');
    }
  }

  // Function to process the secret (handling both encrypted and unencrypted)
  async function processSecret(secretText) {
    try {
      let finalSecretText = secretText;
      let wasEncrypted = false;
      
      try {
        // Try to parse as JSON to see if it's encrypted data
        const possibleEncryptedData = JSON.parse(secretText);
        
        // If it has the structure of encrypted data
        if (possibleEncryptedData.salt && possibleEncryptedData.nonce && possibleEncryptedData.ct) {
          wasEncrypted = true;
          
          const passphrase = passphraseInput ? passphraseInput.value.trim() : '';
          
          // Always attempt decryption, even with empty passphrase
          // This prevents leaking information about whether a passphrase is required
          console.log('🔓 Attempting to decrypt E2EE secret...');
          finalSecretText = await unseal(possibleEncryptedData, passphrase);
          console.log('✓ Successfully decrypted E2EE secret');
        }
        // If JSON parsing succeeds but it's not encrypted data, use the original secret
      } catch (jsonError) {
        // Not JSON, so it's a regular unencrypted secret
        finalSecretText = secretText;
      }
      
      showSecret(finalSecretText, wasEncrypted);
      
    } catch (error) {
      // Generic error message that doesn't reveal any details about the secret state
      showError('Can\'t unlock - link may be expired or needs the correct pass-phrase.');
    }
  }

  // Function to process E2EE secret from new backend format
  async function processE2EESecret(data) {
    try {
      const passphrase = passphraseInput ? passphraseInput.value.trim() : '';
      
      // Always attempt decryption, even with empty passphrase
      console.log('🔓 Attempting to decrypt E2EE secret...');
      const decryptedText = await unseal(data.e2ee, passphrase);
      console.log('✓ Successfully decrypted E2EE secret');
      
      showSecret(decryptedText, true); // true = was encrypted
      
    } catch (error) {
      console.log('Decryption failed, allowing retry:', error.message);
      // Don't reveal error details, just allow retry
      showRetryPassphrase('Unable to decrypt. Please check your passphrase and try again.');
    }
  }

  // Function to process traditional secret from new backend format
  async function processTraditionalSecret(payload, mimeType) {
    // Traditional secrets are already decrypted by the server
    showSecret(payload, false); // false = was not E2EE encrypted
  }

  // Function to show retry passphrase interface
  function showRetryPassphrase(message) {
    resetUI();
    headerTitle.textContent = 'Try Different Passphrase';
    
    // Clear the passphrase input to encourage user to try again
    if (passphraseInput) {
      passphraseInput.value = '';
      passphraseInput.focus();
    }
    
    // Show initial message again with error context
    initialMessage.innerHTML = `
      <div class="text-center">
        <div class="flex items-center gap-2 mx-4 mb-4 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="#f59e0b" viewBox="0 0 256 256">
            <path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,192a88,88,0,1,1,88-88A88.1,88.1,0,0,1,128,216Zm16-40a8,8,0,0,1-8,8,16,16,0,0,1-16-16V128a8,8,0,0,1,0-16,16,16,0,0,1,16,16v40A8,8,0,0,1,144,176ZM112,84a12,12,0,1,1,12,12A12,12,0,0,1,112,84Z"></path>
          </svg>
          <span class="font-body text-sm text-yellow-800">${escapeHTML(message)}</span>
        </div>
        <p class="font-body text-base font-normal leading-normal pb-3 pt-1 px-4" style="color: var(--text-primary);">
          Enter the passphrase for this secret to reveal its contents:
        </p>
        <div class="flex flex-col gap-3 px-4">
          <div class="relative">
            <input
              id="passphraseInput"
              type="password"
              placeholder="Enter passphrase"
              class="form-input w-full h-14 text-base font-body pr-12"
              style="background-color: var(--surface-color); border: 1px solid var(--border-color); color: var(--text-primary);"
            />
            <button
              id="togglePassphraseVisibility"
              type="button"
              class="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 hover:text-gray-700 focus:outline-none"
            >
              <svg id="eyeIcon" xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 256 256">
                <path d="M247.31,124.76c-.35-.79-8.82-19.58-27.65-38.41C194.57,61.26,162.88,48,128,48S61.43,61.26,36.34,86.35C17.51,105.18,9,124,8.69,124.76a8,8,0,0,0,0,6.5c.35.79,8.82,19.57,27.65,38.4C61.43,194.74,93.12,208,128,208s66.57-13.26,91.66-38.34c18.83-18.83,27.3-37.61,27.65-38.4A8,8,0,0,0,247.31,124.76ZM128,192c-30.78,0-57.67-11.19-79.93-33.25A133.47,133.47,0,0,1,25,128,133.33,133.33,0,0,1,48.07,97.25C70.33,75.19,97.22,64,128,64s57.67,11.19,79.93,33.25A133.46,133.46,0,0,1,231,128C223.84,141.46,192.43,192,128,192Zm0-112a48,48,0,1,0,48,48A48.05,48.05,0,0,0,128,80Zm0,80a32,32,0,1,1,32-32A32,32,0,0,1,128,160Z"></path>
              </svg>
              <svg id="eyeSlashIcon" xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 256 256" class="hidden">
                <path d="M53.92,34.62A8,8,0,1,0,42.08,45.38L61.32,66.55C25,88.84,9.38,123.2,8.69,124.76a8,8,0,0,0,0,6.5c.35.79,8.82,19.57,27.65,38.4C61.43,194.74,93.12,208,128,208a127.11,127.11,0,0,0,52.07-10.83l22,24.21a8,8,0,1,0,11.84-10.76Zm47.33,75.84,41.67,45.85a32,32,0,0,1-41.67-45.85ZM128,192c-30.78,0-57.67-11.19-79.93-33.25A133.16,133.16,0,0,1,25,128c4.69-8.79,19.66-33.39,47.35-49.38l18,19.75a48,48,0,0,0,63.66,70l14.73,16.2A112,112,0,0,1,128,192Zm6-95.43a8,8,0,0,1,3-15.72,48.16,48.16,0,0,1,38.77,42.64,8,8,0,0,1-7.22,8.71,6.39,6.39,0,0,1-.75,0,8,8,0,0,1-8-7.26A32.09,32.09,0,0,0,134,96.57Zm113.28,34.69c-.42.94-10.55,23.37-33.36,43.8a8,8,0,1,1-10.67-11.92A132.77,132.77,0,0,0,231.05,128a133.15,133.15,0,0,0-23.12-30.77C185.67,75.19,158.78,64,128,64a118.37,118.37,0,0,0-19.36,1.57A8,8,0,1,1,106,49.79,134,134,0,0,1,128,48c34.88,0,66.57,13.26,91.66,38.35,18.83,18.82,27.3,37.6,27.65,38.39A8,8,0,0,1,247.31,131.26Z"></path>
              </svg>
            </button>
          </div>
          <button
            id="revealButton"
            class="flex min-w-[84px] cursor-pointer items-center justify-center overflow-hidden rounded-full h-12 px-4 text-base font-bold leading-normal tracking-[0.015em] font-body btn-glow"
            style="background-color: var(--secondary-color); color: white;"
          >
            <span class="truncate">Try Again</span>
          </button>
        </div>
      </div>
    `;
    
    initialMessage.classList.remove('hidden');
    
    // Re-setup event handlers for the new elements
    setupPassphraseToggle();
    setupRevealButton();
  }

  // Function to setup passphrase visibility toggle
  function setupPassphraseToggle() {
    const passphraseInput = document.getElementById('passphraseInput');
    const togglePassphraseVisibility = document.getElementById('togglePassphraseVisibility');
    
    if (togglePassphraseVisibility && passphraseInput) {
      togglePassphraseVisibility.addEventListener('click', () => {
        const eyeIcon = document.getElementById('eyeIcon');
        const eyeSlashIcon = document.getElementById('eyeSlashIcon');
        
        if (passphraseInput.type === 'password') {
          passphraseInput.type = 'text';
          eyeIcon.classList.add('hidden');
          eyeSlashIcon.classList.remove('hidden');
        } else {
          passphraseInput.type = 'password';
          eyeIcon.classList.remove('hidden');
          eyeSlashIcon.classList.add('hidden');
        }
      });
    }
  }

  // Function to setup reveal button
  function setupRevealButton() {
    const revealButton = document.getElementById('revealButton');
    if (revealButton) {
      revealButton.addEventListener('click', async () => {
        resetUI();
        loadingContainer.classList.remove('hidden');
        headerTitle.textContent = 'Loading...';

        await fetchSecret(linkId);
      });
    }
  }

  // Function to show the secret with appropriate warning
  function showSecret(secretText, wasEncrypted) {
    resetUI();
    headerTitle.textContent = 'Your One-Time Secret';
    
    const encryptionBadge = wasEncrypted 
      ? '<div class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800 mb-3"><svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" fill="currentColor" viewBox="0 0 256 256" class="mr-1"><path d="M208,80H176V56a48,48,0,0,0-96,0V80H48A16,16,0,0,0,32,96V208a16,16,0,0,0,16,16H208a16,16,0,0,0,16-16V96A16,16,0,0,0,208,80ZM96,56a32,32,0,0,1,64,0V80H96ZM208,208H48V96H208V208Z"></path></svg>End-to-end encrypted</div>'
      : '<div class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800 mb-3"><svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" fill="currentColor" viewBox="0 0 256 256" class="mr-1"><path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,192a88,88,0,1,1,88-88A88.1,88.1,0,0,1,128,216Zm-8-80V80a8,8,0,0,1,16,0v56a8,8,0,0,1-16,0Zm8,36a12,12,0,1,1-12-12A12,12,0,0,1,128,172Z"></path></svg>Server encrypted</div>';
    
    secretContent.innerHTML = `
      <div class="max-w-2xl mx-auto p-6">
        ${encryptionBadge}
        
        <!-- Secret content -->
        <div class="bg-gray-50 border rounded-lg p-4 mb-6 font-mono text-sm overflow-auto max-h-96" style="word-break: break-word;">
          ${escapeHTML(secretText)}
        </div>
        
        <!-- IMPORTANT WARNING: One-time access and anti-enumeration -->
        <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
          <div class="flex items-start gap-3">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="#dc2626" viewBox="0 0 256 256" class="flex-shrink-0 mt-0.5">
              <path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,192a88,88,0,1,1,88-88A88.1,88.1,0,0,1,128,216Zm16-40a8,8,0,0,1-8,8,16,16,0,0,1-16-16V128a8,8,0,0,1,0-16,16,16,0,0,1,16,16v40A8,8,0,0,1,144,176ZM112,84a12,12,0,1,1,12,12A12,12,0,0,1,112,84Z"></path>
            </svg>
            <div>
              <h4 class="font-semibold text-red-800 mb-2">Important: This Secret is Now Gone Forever</h4>
              <ul class="text-sm text-red-700 space-y-1">
                <li><strong>If you close this page, the secret is lost forever.</strong> This is a one-time view.</li>
                <li>Copy or save what you need now - there's no "back" button or second chance.</li>
                <li>For security, our system doesn't reveal if a link is valid or not until you try to open it.</li>
                <li>This protects everyone's privacy and prevents attackers from guessing links.</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    `;
    
    secretContent.classList.remove('hidden');
  }

  // Function to show error messages
  function showError(message) {
    resetUI();
    headerTitle.textContent = 'Unable to Access Secret';
    
    errorContent.innerHTML = `
      <div class="max-w-md mx-auto p-6 text-center">
        <div class="flex justify-center mb-4">
          <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" fill="#dc2626" viewBox="0 0 256 256">
            <path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,192a88,88,0,1,1,88-88A88.1,88.1,0,0,1,128,216Zm16-40a8,8,0,0,1-8,8,16,16,0,0,1-16-16V128a8,8,0,0,1,0-16,16,16,0,0,1,16,16v40A8,8,0,0,1,144,176ZM112,84a12,12,0,1,1,12,12A12,12,0,0,1,112,84Z"></path>
          </svg>
        </div>
        <p class="text-gray-700 mb-4">${escapeHTML(message)}</p>
        <div class="text-sm text-gray-600 bg-gray-50 rounded-lg p-3">
          <p class="mb-2"><strong>This could mean:</strong></p>
          <ul class="text-left space-y-1">
            <li>• The link has already been viewed (one-time use)</li>
            <li>• The link has expired</li>
            <li>• The wrong passphrase was used (if encrypted)</li>
            <li>• The link was typed incorrectly</li>
          </ul>
          <p class="mt-2 text-xs">For security, we don't reveal which specific reason applies.</p>
        </div>
      </div>
    `;
    
    errorContent.classList.remove('hidden');
  }
});