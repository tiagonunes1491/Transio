/* view.js - JavaScript specific to view.html */
/* global escapeHTML */

document.addEventListener('DOMContentLoaded', () => {
  // Extract the link ID from the URL hash
  const hash = window.location.hash.substring(1); // Remove the # character
  const linkId = hash;

  // Get DOM elements
  const headerTitle = document.getElementById('headerTitle');
  const initialMessage = document.getElementById('initialMessage');
  const loadingContainer = document.getElementById('loadingContainer');
  const secretContent = document.getElementById('secretContent');
  const errorContent = document.getElementById('errorContent');

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
    showError('Invalid link. No secret ID was provided.');
    return;
  }

  // Initially show loading and check if secret exists
  resetUI();
  loadingContainer.classList.remove('hidden');
  headerTitle.textContent = 'Checking...';

  checkSecretExists(linkId);
  // Function to check if the secret exists without revealing it
  async function checkSecretExists(linkId) {
    try {
      // Determine API endpoint based on environment
      const isDevelopment =
        window.location.hostname === 'localhost' ||
        window.location.hostname === '127.0.0.1' ||
        window.location.protocol === 'file:';
      const apiEndpoint = isDevelopment
        ? `http://127.0.0.1:5000/api/share/secret/${linkId}` // Local dev
        : `/api/share/secret/${linkId}`; // Deployed

      // Just check if the secret exists without revealing it
      const response = await fetch(apiEndpoint, {
        method: 'HEAD', // Only check headers, don't retrieve content
        headers: {
          Accept: 'application/json'
        }
      });

      // Always hide loading state when response comes back
      resetUI();

      if (response.status === 404) {
        // Secret doesn't exist, show not found message immediately
        showNotFound();
        return;
      }

      if (!response.ok) {
        // Some other error, show generic error message
        showError(`Server returned error: ${response.status}`);
        return;
      }

      // Secret exists but we don't reveal it yet, just update the UI to indicate it's ready
      headerTitle.textContent = 'Secret Available';
      initialMessage.classList.remove('hidden');

      // Add click event listener to the reveal button
      const revealButton = document.getElementById('revealButton');
      if (revealButton) {
        revealButton.addEventListener('click', async () => {
          resetUI();
          loadingContainer.classList.remove('hidden');
          headerTitle.textContent = 'Loading...';

          await fetchSecret(linkId);
        });
      }
    } catch (error) {
      // Always hide loading state on error
      resetUI();
      showError(`Failed to check if the secret exists: ${error.message}`);
    }
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

      if (response.status === 404) {
        showNotFound();
        return;
      }

      if (!response.ok) {
        try {
          const errorData = await response.json();
          throw new Error(errorData.error || `Server returned error: ${response.status}`);
        } catch (jsonError) {
          throw new Error(`Server returned error: ${response.status}`);
        }
      }

      try {
        // Handle successful response
        const data = await response.json();

        if (data.error) {
          showError(data.error);
        } else if (data.secret) {
          showSecret(data.secret);
        } else {
          showError('Received unexpected data format from server.');
        }
      } catch (jsonParseError) {
        showError(`Failed to parse response: ${jsonParseError.message}`);
      }
    } catch (error) {
      showError(`Failed to retrieve the secret: ${error.message}`);
    }
  }

  // Function to display the secret
  function showSecret(secretText) {
    resetUI();
    headerTitle.textContent = 'Your One-Time Secret';
    secretContent.innerHTML = `
            <div class="border border-gray-200 rounded-lg p-4 mx-4 mb-4" style="background-color: var(--surface-color);">
                <div class="flex items-center gap-2 mb-3">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="#28a745" viewBox="0 0 256 256">
                        <path d="M229.66,77.66l-128,128a8,8,0,0,1-11.32,0l-56-56a8,8,0,0,1,11.32-11.32L96,188.69,218.34,66.34a8,8,0,0,1,11.32,11.32Z"></path>
                    </svg>
                    <span class="text-green-600 text-sm font-medium font-body">Your secret has been successfully revealed!</span>
                </div>
            </div>
            <div class="border border-gray-200 rounded-lg p-4 mx-4 mb-4" style="background-color: var(--surface-color);">
                <div class="font-body text-base font-normal leading-relaxed whitespace-pre-wrap" style="color: var(--text-primary);">${escapeHTML(secretText)}</div>
            </div>
            <div class="flex items-center gap-2 mx-4 mb-4">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="var(--secondary-color)" viewBox="0 0 256 256">
                    <path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,192a88,88,0,1,1,88-88A88.1,88.1,0,0,1,128,216Zm16-40a8,8,0,0,1-8,8,16,16,0,0,1-16-16V128a8,8,0,0,1,0-16,16,16,0,0,1,16,16v40A8,8,0,0,1,144,176ZM112,84a12,12,0,1,1,12,12A12,12,0,0,1,112,84Z"></path>
                </svg>
                <span class="font-body text-sm" style="color: var(--text-secondary);">This secret has now been deleted and cannot be accessed again.</span>
            </div>
            <div class="flex px-4 py-3 justify-center">
                <button
                    onclick="window.location.href = 'index.html'"
                    class="flex min-w-[84px] max-w-[480px] cursor-pointer items-center justify-center overflow-hidden rounded-full h-10 px-4 text-sm font-bold leading-normal tracking-[0.015em] font-body btn-glow"
                    style="background-color: var(--secondary-color); color: white;"
                >
                    <span class="truncate">Create New Secret</span>
                </button>
            </div>
        `;
    secretContent.classList.remove('hidden');
  }

  // Function to show "not found" message
  function showNotFound() {
    resetUI();
    headerTitle.textContent = 'Secret Not Found';
    errorContent.innerHTML = `
            <div class="text-center">
                <div class="text-6xl mb-4">
                    <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" fill="var(--text-light)" viewBox="0 0 256 256" class="mx-auto">
                        <path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,192a88,88,0,1,1,88-88A88.1,88.1,0,0,1,128,216ZM80,108A12,12,0,1,1,92,96,12,12,0,0,1,80,108Zm88,0a12,12,0,1,1-12-12A12,12,0,0,1,168,108Zm-12,60c-17.74,0-32-11.45-32-25.61a8,8,0,1,1,16,0c0,5.23,8.22,9.61,16,9.61s16-4.38,16-9.61a8,8,0,1,1,16,0C188,156.55,173.74,168,156,168Z"></path>
                    </svg>
                </div>
                <p class="font-body text-base font-normal leading-normal pb-3 pt-1 px-4" style="color: var(--text-primary);">The secret link is invalid, has expired, or has already been viewed.</p>
                <p class="font-body text-sm font-normal leading-normal pb-3 pt-1 px-4" style="color: var(--text-secondary);">For security reasons, secrets can only be accessed once.</p>
                <div class="flex px-4 py-3 justify-center">
                    <button
                        onclick="window.location.href = 'index.html'"
                        class="flex min-w-[84px] max-w-[480px] cursor-pointer items-center justify-center overflow-hidden rounded-full h-10 px-4 text-sm font-bold leading-normal tracking-[0.015em] font-body btn-glow"
                        style="background-color: var(--secondary-color); color: white;"
                    >
                        <span class="truncate">Create New Secret</span>
                    </button>
                </div>
            </div>
        `;
    errorContent.classList.remove('hidden');
  }

  // Function to show error message
  function showError(message) {
    resetUI();
    headerTitle.textContent = 'An Error Occurred';
    errorContent.innerHTML = `
            <div class="text-center">
                <div class="text-6xl mb-4">
                    <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" fill="var(--secondary-color)" viewBox="0 0 256 256" class="mx-auto">
                        <path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,192a88,88,0,1,1,88-88A88.1,88.1,0,0,1,128,216Zm16-40a8,8,0,0,1-8,8,16,16,0,0,1-16-16V128a8,8,0,0,1,0-16,16,16,0,0,1,16,16v40A8,8,0,0,1,144,176ZM112,84a12,12,0,1,1,12,12A12,12,0,0,1,112,84Z"></path>
                    </svg>
                </div>
                <p class="font-body text-base font-normal leading-normal pb-3 pt-1 px-4" style="color: var(--text-primary);">${escapeHTML(message)}</p>
                <div class="flex px-4 py-3 justify-center">
                    <button
                        onclick="window.location.href = 'index.html'"
                        class="flex min-w-[84px] max-w-[480px] cursor-pointer items-center justify-center overflow-hidden rounded-full h-10 px-4 text-sm font-bold leading-normal tracking-[0.015em] font-body btn-glow"
                        style="background-color: var(--secondary-color); color: white;"
                    >
                        <span class="truncate">Create New Secret</span>
                    </button>
                </div>
            </div>
        `;
    errorContent.classList.remove('hidden');
  }

  // Help modal functionality
  function showHelpModal() {
    helpModal.classList.remove('hidden');
    document.body.style.overflow = 'hidden'; // Prevent background scrolling
  }

  function hideHelpModal() {
    helpModal.classList.add('hidden');
    document.body.style.overflow = ''; // Restore scrolling
  }

  // Help button click handler
  if (helpButton) {
    helpButton.addEventListener('click', showHelpModal);
  }

  // Close modal handlers
  if (closeHelpModal) {
    closeHelpModal.addEventListener('click', hideHelpModal);
  }

  if (closeHelpModalButton) {
    closeHelpModalButton.addEventListener('click', hideHelpModal);
  }

  // Close modal when clicking outside of it
  if (helpModal) {
    helpModal.addEventListener('click', e => {
      if (e.target === helpModal) {
        hideHelpModal();
      }
    });
  }

  // Close modal with Escape key
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && !helpModal.classList.contains('hidden')) {
      hideHelpModal();
    }
  });
});
