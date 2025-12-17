// Visitor Counter - Connects to Azure Function API

async function updateVisitorCount() {
    const countElement = document.getElementById('visitor-count');
    
    try {
        // Replace with your actual Azure Function URL after deployment
        // Format: https://YOUR-FUNCTION-APP-NAME.azurewebsites.net/api/GetVisitorCount
        const apiUrl = 'resume-counter-api-c6cecmbug0hkgyec.eastus-01.azurewebsites.net';
        
        // Show loading state
        countElement.textContent = 'Loading...';
        
        const response = await fetch(apiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        
        // Animate the counter (optional but looks cool)
        animateCount(countElement, data.count);
        
    } catch (error) {
        console.error('Error updating visitor count:', error);
        countElement.textContent = 'Unable to load';
        countElement.style.color = '#888';
    }
}

// Optional: Animate the counter numbers
function animateCount(element, targetCount) {
    let currentCount = 0;
    const increment = Math.ceil(targetCount / 20);
    const duration = 1000; // 1 second
    const stepTime = duration / 20;
    
    const timer = setInterval(() => {
        currentCount += increment;
        if (currentCount >= targetCount) {
            currentCount = targetCount;
            clearInterval(timer);
        }
        element.textContent = currentCount;
    }, stepTime);
}

// Run when page loads
document.addEventListener('DOMContentLoaded', updateVisitorCount);