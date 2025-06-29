/* index.js - JavaScript specific to index.html */
/* global formatDate, truncateLink, copyToClipboard */

// EFF Large Wordlist for secure passphrase generation
let PASSPHRASE_WORDS = [];
let wordlistReady = null; // Promise to track wordlist loading

// Load the EFF wordlist on page load
async function loadWordlist() {
  if (wordlistReady) {
    return wordlistReady; // Return cached promise if already loading/loaded
  }

  wordlistReady = (async () => {
    try {
      console.log('Loading EFF wordlist...');
      const response = await fetch('eff_large_wordlist.txt');
      
      if (!response.ok) {
        throw new Error(`Failed to fetch wordlist: ${response.status} ${response.statusText}`);
      }
      
      const text = await response.text();
      // Parse the wordlist (format: "11111\tabacus")
      PASSPHRASE_WORDS = text.trim().split('\n').map(line => {
        const parts = line.split('\t');
        return parts[1]; // Return just the word, not the dice number
      });
      
      console.log(`✓ Loaded ${PASSPHRASE_WORDS.length} words for passphrase generation`);
      return PASSPHRASE_WORDS;
    } catch (error) {
      console.error('✗ Failed to load EFF wordlist:', error);
      console.error('Make sure eff_large_wordlist.txt exists in the same directory');
      throw error;
    }
  })();

  return wordlistReady;
}

// Generate secure random index for word selection (unbiased, using Uint16)
function getSecureRandomIndex(maxIndex) {
  // Use rejection sampling to avoid bias with Uint16Array
  const maxValid = Math.floor(0xFFFF / maxIndex) * maxIndex;
  let randomValue;
  do {
    const array = new Uint16Array(1);
    crypto.getRandomValues(array);
    randomValue = array[0];
  } while (randomValue >= maxValid);
  
  return randomValue % maxIndex;
}

// Generate a secure passphrase with specified number of words
async function generatePassphrase(wordCount = 6) {
  // Ensure wordlist is loaded before generating passphrase
  await loadWordlist();
  
  if (PASSPHRASE_WORDS.length === 0) {
    throw new Error('Wordlist not available for passphrase generation');
  }
  
  const selectedWords = [];
  for (let i = 0; i < wordCount; i++) {
    const randomIndex = getSecureRandomIndex(PASSPHRASE_WORDS.length);
    selectedWords.push(PASSPHRASE_WORDS[randomIndex]);
  }
  return selectedWords.join('-');
}

// Passphrase strength calculation
function calculatePassphraseStrength(passphrase) {
  const words = passphrase.trim()
    .split(/[^A-Za-z]+/)               // split by hyphen / spaces
    .filter(Boolean);                  // remove empties

  if (words.length === 0) {
    return { strength: 'weak', label: '-', entropy: 0 };
  }

  const BITS_PER_WORD = Math.log2(7776);      // ≈ 12.93 (EFF wordlist size)
  const entropy = words.length * BITS_PER_WORD;
  
  let strength, label;
  if (entropy < 60) {        // < 5 Diceware words
    strength = 'weak';
    label = 'weak';
  } else if (entropy < 77) { // 5-6 Diceware words
    strength = 'ok';
    label = 'ok';
  } else {                   // ≥ 6 Diceware words
    strength = 'strong';
    label = 'strong';
  }

  return { strength, label, entropy: Math.round(entropy) };
}

// Update strength meter display
function updateStrengthMeter(passphrase) {
  const strengthLabel = document.getElementById('strengthLabel');
  if (!strengthLabel) return;

  const { strength, label, entropy } = calculatePassphraseStrength(passphrase);
  
  // Set color based on strength
  let color;
  switch (strength) {
    case 'weak':
      color = '#dc2626';  // red
      break;
    case 'ok':
      color = '#f59e0b';  // amber
      break;
    case 'strong':
      color = '#10b981';  // green
      break;
    default:
      color = 'var(--text-color-subtle)';
  }
  
  strengthLabel.textContent = label;
  strengthLabel.style.color = color;
  strengthLabel.style.fontWeight = 'bold';
}

document.addEventListener('DOMContentLoaded', async () => {
  // Load the EFF wordlist first
  await loadWordlist();
  
  const secretInput = document.getElementById('secretMessageInput');
  const mainCreateLinkButton = document.getElementById('mainCreateLinkButton');
  const resultArea = document.getElementById('resultArea');
  const secretLinkInput = document.getElementById('secretLinkInput');
  const copyLinkButton = document.getElementById('copyLinkButton');
  const historySection = document.getElementById('historySection');
  const noSecretsSection = document.getElementById('noSecretsSection');
  const linksHistory = document.getElementById('linksHistory');
  const floatingButton = document.getElementById('floatingCreateButton');
  const createSectionToObserve = document.getElementById('createSection');
  const noSecretsCreateButton = document.getElementById('noSecretsCreateButton');
  
  // E2EE elements
  const e2eeCheckbox = document.getElementById('e2eeCheckbox');
  const passphraseContainer = document.getElementById('passphraseContainer');
  const passphraseInput = document.getElementById('passphraseInput');
  const regeneratePassphraseBtn = document.getElementById('regeneratePassphraseBtn');
  const copyPassphraseButton = document.getElementById('copyPassphraseButton');
  const strengthMeter = document.getElementById('strengthMeter');

  let generatedLinks = [];
  try {
    const savedLinks = localStorage.getItem('secretSharerLinks');
    if (savedLinks) {
      generatedLinks = JSON.parse(savedLinks);
    }
  } catch (error) {
    // Failed to load history from localStorage
  }
  updateHistoryUI();

  const isDevelopment =
    window.location.hostname === 'localhost' ||
    window.location.hostname === '127.0.0.1' ||
    window.location.protocol === 'file:';
  const shareApiEndpoint = isDevelopment ? 'http://127.0.0.1:5000/api/share' : '/api/share';
  const revealLinkBasePath = `${window.location.origin}/view.html#`;

  // E2EE checkbox toggle functionality
  if (e2eeCheckbox && passphraseContainer) {
    e2eeCheckbox.addEventListener('change', async function() {
      if (this.checked) {
        passphraseContainer.classList.remove('hidden');
        // Generate initial passphrase if input is empty
        if (passphraseInput && !passphraseInput.value.trim()) {
          try {
            passphraseInput.value = 'Generating passphrase...';
            updateStrengthMeter('');
            passphraseInput.value = await generatePassphrase();
            updateStrengthMeter(passphraseInput.value);
          } catch (error) {
            console.error('Failed to generate passphrase:', error);
            passphraseInput.value = 'Error loading wordlist';
            updateStrengthMeter('');
          }
        }
        // Focus on passphrase input when checkbox is checked
        setTimeout(() => {
          if (passphraseInput) {
            passphraseInput.focus();
            passphraseInput.select(); // Select the generated passphrase
          }
        }, 100);
      } else {
        passphraseContainer.classList.add('hidden');
        // Clear passphrase when unchecked
        if (passphraseInput) {
          passphraseInput.value = '';
          updateStrengthMeter('');
        }
      }
    });
  }

  // Regenerate passphrase button functionality
  if (regeneratePassphraseBtn && passphraseInput) {
    regeneratePassphraseBtn.addEventListener('click', async function() {
      try {
        const originalText = passphraseInput.value;
        passphraseInput.value = 'Generating...';
        updateStrengthMeter('');
        passphraseInput.value = await generatePassphrase();
        updateStrengthMeter(passphraseInput.value);
        passphraseInput.focus();
        passphraseInput.select(); // Select the new passphrase
      } catch (error) {
        console.error('Failed to regenerate passphrase:', error);
        passphraseInput.value = 'Error generating passphrase';
        updateStrengthMeter('');
      }
    });
  }

  // Passphrase input change listener for strength meter
  if (passphraseInput) {
    passphraseInput.addEventListener('input', function() {
      updateStrengthMeter(this.value);
    });
  }

  // Copy passphrase button functionality
  if (copyPassphraseButton && passphraseInput) {
    copyPassphraseButton.addEventListener('click', () => {
      copyToClipboard(passphraseInput.value, copyPassphraseButton);
    });
  }

  async function createSecret(buttonTrigger) {
    const secretText = secretInput.value;
    if (!secretText.trim()) {
      secretInput.focus();
      return;
    }

    const originalButtonText = buttonTrigger.innerHTML;
    buttonTrigger.innerHTML = '<span class="truncate">Encrypting & Creating...</span>';
    buttonTrigger.disabled = true;

    try {
      const response = await fetch(shareApiEndpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ secret: secretText })
      });
      let responseData;
      try {
        responseData = await response.json();
      } catch (jsonError) {
        const errorText = await response.text();
        throw new Error(
          `Server returned non-JSON response: ${response.status} - ${errorText || response.statusText}`
        );
      }
      if (response.ok && responseData.link_id) {
        const secretLink = `${revealLinkBasePath}${responseData.link_id}`;
        const newLinkData = {
          url: secretLink,
          timestamp: new Date().toISOString(),
          id: responseData.link_id
        };
        generatedLinks.unshift(newLinkData);
        if (generatedLinks.length > 10) {
          generatedLinks = generatedLinks.slice(0, 10);
        }
        localStorage.setItem('secretSharerLinks', JSON.stringify(generatedLinks));
        resultArea.classList.remove('hidden');
        secretLinkInput.value = secretLink;
        secretInput.value = ''; // Clear input after successful creation
        resultArea.scrollIntoView({ behavior: 'smooth', block: 'center' });
        updateHistoryUI(true); // Mark as new link for animation
      } else {
        const errorMessage =
          responseData.error || `Failed to share secret. Status: ${response.status}`;
        resultArea.classList.remove('hidden');
        secretLinkInput.value = `Error: ${errorMessage}`;
      }
    } catch (error) {
      resultArea.classList.remove('hidden');
      secretLinkInput.value = 'Error: Failed to create secret. Check console & backend.';
    } finally {
      buttonTrigger.innerHTML = originalButtonText;
      buttonTrigger.disabled = false;
    }
  }

  function updateHistoryUI(hasNewLink = false) {
    if (generatedLinks.length === 0) {
      historySection.classList.add('hidden');
      noSecretsSection.classList.remove('hidden');
      return;
    }
    historySection.classList.remove('hidden');
    noSecretsSection.classList.add('hidden');
    linksHistory.innerHTML = '';
    generatedLinks.forEach((linkData, index) => {
      const linkItem = document.createElement('div');
      // Adapted styles for history items
      linkItem.className =
        'flex items-center justify-between p-3 border rounded-lg mb-3 transition-all duration-300 hover:shadow-md';
      linkItem.style.backgroundColor = 'var(--accent-color-white)';
      linkItem.style.borderColor = '#e0e0e0'; // Softer border
      linkItem.onmouseover = () => {
        linkItem.style.borderColor = 'var(--secondary-color)';
      };
      linkItem.onmouseout = () => {
        linkItem.style.borderColor = '#e0e0e0';
      };

      if (index === 0 && hasNewLink) {
        // Highlight new link with secondary color
        linkItem.style.borderColor = 'var(--secondary-color)';
        linkItem.style.boxShadow = '0 0 0 2px rgba(32, 106, 93, 0.3)';
        setTimeout(() => {
          linkItem.style.borderColor = '#e0e0e0';
          linkItem.style.boxShadow = 'none';
        }, 3000);
      }
      linkItem.innerHTML = `
                <div class="flex flex-col gap-1 flex-1 min-w-0">
                    <span class="text-xs font-medium" style="color: var(--text-color-subtle);">SHARED ${formatDate(linkData.timestamp).toUpperCase()}</span>
                    <a href="${linkData.url}" target="_blank" class="text-sm hover:text-opacity-75 transition-colors truncate block font-medium" title="${linkData.url}" style="color: var(--secondary-color);">
                        <svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" fill="currentColor" viewBox="0 0 256 256" class="inline mr-1 align-middle">
                            <path d="M136,136H40a8,8,0,0,1,0-16h96a8,8,0,0,1,0,16Zm0-48H40a8,8,0,0,1,0-16h96a8,8,0,0,1,0,16ZM40,184h64a8,8,0,0,0,0-16H40a8,8,0,0,0,0,16Zm176-80v96a16,16,0,0,1-16,16H56a16,16,0,0,1-16-16V56A16,16,0,0,1,56,40h96a8,8,0,0,1,5.66,2.34l48,48A8,8,0,0,1,208,96v8a8,8,0,0,1-16,0V99.31l-42.34-42.34H56V200H200V104Z"></path>
                        </svg>
                        ${truncateLink(linkData.url)}
                    </a>
                </div>
                <button data-link="${linkData.url}" class="history-copy-button flex-shrink-0 flex items-center justify-center w-9 h-9 rounded-md text-white transition-all duration-300 ml-3 p-2 border btn-glow" title="Copy link" style="background-color: var(--text-color-subtle); border-color: transparent;">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 256 256"><path d="M216,32H88a8,8,0,0,0-8,8V80H40a8,8,0,0,0-8,8V216a8,8,0,0,0,8,8H168a8,8,0,0,0,8-8V176h40a8,8,0,0,0,8-8V40A8,8,0,0,0,216,32ZM160,208H48V96H80v72a8,8,0,0,0,8,8h72Zm48-48H96V48H208Z"></path></svg>
                </button>`;
      linksHistory.appendChild(linkItem);
    });
    document.querySelectorAll('.history-copy-button').forEach(btn => {
      btn.addEventListener('click', () => copyToClipboard(btn.dataset.link, btn));
    });
  }

  // Event listeners
  if (mainCreateLinkButton) {
    mainCreateLinkButton.addEventListener('click', async e => {
      e.preventDefault();
      await createSecret(mainCreateLinkButton);
    });
  }
  if (noSecretsCreateButton) {
    noSecretsCreateButton.addEventListener('click', e => {
      e.preventDefault();
      if (secretInput) secretInput.focus();
      if (createSectionToObserve) {
        createSectionToObserve.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    });
  }
  if (copyLinkButton) {
    copyLinkButton.addEventListener('click', () =>
      copyToClipboard(secretLinkInput.value, copyLinkButton)
    );
  }
  if (secretInput) {
    secretInput.addEventListener('keypress', e => {
      if (e.key === 'Enter') {
        e.preventDefault();
        if (mainCreateLinkButton) mainCreateLinkButton.click();
      }
    });
  }

  // Floating button functionality
  if (floatingButton && createSectionToObserve) {
    const observer = new IntersectionObserver(
      entries => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            floatingButton.classList.add('hidden');
          } else {
            floatingButton.classList.remove('hidden');
          }
        });
      },
      { threshold: 0.1 }
    );
    observer.observe(createSectionToObserve);
    floatingButton.addEventListener('click', () => {
      createSectionToObserve.scrollIntoView({ behavior: 'smooth', block: 'center' });
      setTimeout(() => {
        if (secretInput) secretInput.focus();
      }, 500);
    });

    function animateFloatingButton() {
      if (floatingButton && !floatingButton.classList.contains('hidden')) {
        floatingButton.classList.add('floating-bounce');
        setTimeout(() => {
          floatingButton.classList.remove('floating-bounce');
        }, 800);
      }
    }

    function scheduleNextAnimation() {
      const interval = 5000 + Math.random() * 3000;
      setTimeout(() => {
        animateFloatingButton();
        scheduleNextAnimation();
      }, interval);
    }

    setTimeout(scheduleNextAnimation, 3000);
  } else {
    if (floatingButton) floatingButton.classList.add('hidden');
  }
});
