document.addEventListener('DOMContentLoaded', () => {
    const secretInput = document.getElementById('secretInput');
    const shareSecretButton = document.getElementById('shareSecretButton');
    const resultArea = document.getElementById('resultArea');

    // Create a loading spinner element
    const spinner = document.createElement('div');
    spinner.className = 'spinner';
    spinner.style.display = 'none'; // Hide it initially

    // Determine API endpoints
    const isDevelopment = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
    
    // Endpoint for POSTing the secret
    const shareApiEndpoint = isDevelopment 
        ? 'http://127.0.0.1:5000/share' // Local dev: backend directly on port 5000
        : '/api/share';                 // Deployed: via Ingress /api

    // Base URL for constructing the reveal link
    const revealLinkBasePath = isDevelopment
        ? 'http://127.0.0.1:5000/secret/' // Local dev
        : `${window.location.origin}/api/secret/`; // Deployed

    shareSecretButton.addEventListener('click', async () => {
        const secretText = secretInput.value;
        resultArea.innerHTML = ''; // Clear previous results
        resultArea.className = ''; // Reset any previous styling

        if (!secretText.trim()) {
            resultArea.innerHTML = '<p class="error-message">Please enter a secret to share.</p>';
            return;
        }

        // Show loading state and save the original button content
        const originalButtonContent = shareSecretButton.innerHTML;
        shareSecretButton.disabled = true;
        shareSecretButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Processing...';

        try {
            const response = await fetch(shareApiEndpoint, {
                method: 'POST',                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                },
                body: JSON.stringify({ secret: secretText }),
            });

            // Attempt to parse JSON response
            let responseData;
            try {
                responseData = await response.json();
            } catch (jsonError) {
                const errorText = await response.text();
                console.error('Failed to parse JSON response. Raw response:', errorText);
                throw new Error(`Server returned non-JSON response: ${response.status} - ${errorText || response.statusText}`);
            }            if (response.ok && responseData.link_id) {
                const secretLink = `${revealLinkBasePath}${responseData.link_id}`;
                  resultArea.innerHTML = `
                    <div class="success-result">
                        <div class="success-icon">
                            <i class="fas fa-check-circle"></i>
                        </div>
                        <p class="success-message">Secret shared successfully!</p>
                        
                        <div id="linkContainer">
                            <div class="link-box">
                                <a href="${secretLink}" target="_blank" id="generatedLink" title="${secretLink}">
                                    <i class="fas fa-lock"></i> One-time secret link
                                </a>
                                <input type="hidden" id="hiddenLink" value="${secretLink}">
                            </div>
                        </div>
                        
                        <p class="warning-message">
                            <i class="fas fa-exclamation-triangle"></i>
                            <span>This link will only work once and then the secret will be permanently deleted.</span>
                        </p>
                    </div>
                `;

                const copyButton = document.createElement('button');
                copyButton.className = 'copy-btn';
                copyButton.innerHTML = '<i class="fas fa-copy"></i>';
                  copyButton.onclick = () => {
                    const hiddenLink = document.getElementById('hiddenLink');
                    navigator.clipboard.writeText(hiddenLink.value).then(() => {
                        copyButton.classList.add('copied');
                        copyButton.innerHTML = '<i class="fas fa-check"></i>';
                        setTimeout(() => { 
                            copyButton.classList.remove('copied');
                            copyButton.innerHTML = '<i class="fas fa-copy"></i>'; 
                        }, 2000);
                    }).catch(err => {
                        console.error('Failed to copy link: ', err);
                        // Fallback for older browsers
                        try {
                            const textArea = document.createElement("textarea");
                            textArea.value = hiddenLink.value;
                            document.body.appendChild(textArea);
                            textArea.focus();
                            textArea.select();
                            document.execCommand('copy');
                            document.body.removeChild(textArea);
                            copyButton.classList.add('copied');
                            copyButton.innerHTML = '<i class="fas fa-check"></i>';
                            setTimeout(() => { 
                                copyButton.classList.remove('copied');
                                copyButton.innerHTML = '<i class="fas fa-copy"></i>'; 
                            }, 2000);
                        } catch (fallbackErr) {
                            console.error('Fallback copy failed: ', fallbackErr);
                            alert('Failed to copy link. Please copy it manually.');
                        }
                    });
                };
                
                // Append copy button to the link container
                const linkContainer = document.getElementById('linkContainer');
                if (linkContainer) {
                    linkContainer.appendChild(copyButton);
                }

                secretInput.value = ''; // Clear the textarea
            } else {
                // Handle errors from the backend
                const errorMessage = responseData.detail || responseData.error || `Failed to share secret. Status: ${response.status}`;
                resultArea.innerHTML = `<p class="error-message"><i class="fas fa-exclamation-circle"></i> ${escapeHTML(errorMessage)}</p>`;
            }
        } catch (error) {
            // Handle network errors or other issues
            console.error('Error sharing secret:', error);
            resultArea.innerHTML = `
                <p class="error-message">
                    <i class="fas fa-times-circle"></i> 
                    An unexpected error occurred. Ensure the backend is reachable. 
                    <span style="display: block; margin-top: 8px; font-size: 14px; opacity: 0.8;">
                        Error: ${escapeHTML(error.message)}
                    </span>
                </p>`;
        } finally {
            // Restore button to original state
            shareSecretButton.disabled = false;
            shareSecretButton.innerHTML = originalButtonContent;
        }
    });    // Helper function to escape HTML to prevent XSS
    function escapeHTML(str) {
        const div = document.createElement('div');
        div.appendChild(document.createTextNode(str));
        return div.innerHTML;
    }
    
    // Helper function to truncate long links for display
    function truncateLink(url) {
        if (url.length <= 60) return url;
        
        const urlObj = new URL(url);
        const path = urlObj.pathname;
        const id = path.split('/').pop();
        
        // Keep the protocol, host and shorten the ID
        return `${urlObj.protocol}//${urlObj.host}/.../${id.substring(0, 8)}...`;
    }
});