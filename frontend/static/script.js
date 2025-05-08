document.addEventListener('DOMContentLoaded', () => {
    const secretInput = document.getElementById('secretInput');
    const shareSecretButton = document.getElementById('shareSecretButton');
    const resultArea = document.getElementById('resultArea');

    // Create a loading spinner element
    const spinner = document.createElement('div');
    spinner.className = 'spinner';
    spinner.style.display = 'none';
    
    // Fix: Append spinner to the container div instead of a non-existent form
    document.querySelector('.container').appendChild(spinner);
    
    // Alternatively, you could insert it after the button
    // shareSecretButton.parentNode.insertBefore(spinner, shareSecretButton.nextSibling);

    // Define the backend API endpoint
    // When using python -m http.server, we'll always be on localhost with different ports
    const isDevelopment = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
    const shareApiUrl = isDevelopment 
        ? 'http://127.0.0.1:5000/share'  // Backend on port 5000
        : '/api/share';  // Production environment with API at /api path

    shareSecretButton.addEventListener('click', async () => {
        const secretText = secretInput.value;
        resultArea.innerHTML = ''; // Clear previous results

        if (!secretText.trim()) {
            resultArea.innerHTML = '<p class="error-message">Please enter a secret to share.</p>';
            return;
        }

        // Disable button and show loading spinner
        shareSecretButton.disabled = true;
        shareSecretButton.textContent = 'Sharing...';
        spinner.style.display = 'inline-block';

        try {
            const response = await fetch(shareApiUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ secret: secretText }),
            });

            const responseData = await response.json(); // Try to parse JSON regardless of response.ok

            if (response.ok) {
                // Construct the shareable link using the link_id
                const secretLink = `http://127.0.0.1:5000/secret/${responseData.link_id}`;
                resultArea.innerHTML = `
                    <p>Secret shared successfully!</p>
                    <p>One-time access link: <a href="${secretLink}" target="_blank">${secretLink}</a></p>
                    <p><strong>Important:</strong> Copy this link now. It will not be shown again.</p>
                `;
                secretInput.value = ''; // Clear the textarea after successful sharing

                // Add a button next to the link
                const copyButton = document.createElement('button');
                copyButton.textContent = 'Copy Link';
                copyButton.onclick = () => {
                    navigator.clipboard.writeText(secretLink);
                    copyButton.textContent = 'Copied!';
                    setTimeout(() => { copyButton.textContent = 'Copy Link'; }, 2000);
                };

                resultArea.appendChild(copyButton); // Add the button to the result area
            } else {
                // Handle errors from the backend (e.g., validation errors, server errors)
                const errorMessage = responseData.error || `Failed to share secret. Status: ${response.status}`;
                resultArea.innerHTML = `<p class="error-message">${escapeHTML(errorMessage)}</p>`;
            }
        } catch (error) {
            // Handle network errors or other issues with the fetch request
            console.error('Error sharing secret:', error);
            resultArea.innerHTML = '<p class="error-message">An unexpected error occurred. Check the console and ensure the backend is running.</p>';
        } finally {
            // Re-enable button and hide spinner
            shareSecretButton.disabled = false;
            shareSecretButton.textContent = 'Share Secret';
            spinner.style.display = 'none';
        }
    });

    // Helper function to escape HTML to prevent XSS if displaying user-controlled error messages (though backend errors should be safe)
    function escapeHTML(str) {
        const p = document.createElement('p');
        p.appendChild(document.createTextNode(str));
        return p.innerHTML;
    }
});