// highlight.js
document.addEventListener('DOMContentLoaded', function() {
    // Get the current URL path
    const currentPath = window.location.pathname;
    
    // Extract the filename from the URL path
    const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1);
    
    // Highlight the corresponding sidebar link
    const links = document.querySelectorAll('.sidebar a');
    links.forEach(link => {
        if (link.getAttribute('href') === currentPage) {
            link.classList.add('active');
        }
    });
});
