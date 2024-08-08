// highlight.js
document.addEventListener('DOMContentLoaded', function () {
    // Get the current URL path
    const currentPath = window.location.pathname;

    // Extract the filename from the URL path
    const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1);
    // Split the URL path into segments and Extract the parent directory from the URL path
    const pathSegments = currentPath.split('/');
    const parentDirectory = pathSegments.length > 2 ? pathSegments[pathSegments.length - 2] : '';

    // Highlight the corresponding sidebar link
    const links = document.querySelectorAll('.sidebar a');
    links.forEach(link => {
        const linkId = link.getAttribute('id');
        const linkHref = link.getAttribute('href');
        // Handle root as home
        if (linkHref === 'https://bellsworth.info/' && currentPage === '') {
            link.classList.add('active');
        // Handle index.html, project.html, blog.html pages
        } else if (linkHref === currentPage) {
            link.classList.add('active');
        // Handles sub-pages of "Projects"
        } else if (parentDirectory === 'projects' && linkId === 'projects') {
            link.classList.add('active');
        // Handles sub-pages of "Blog"
        } else if (parentDirectory === 'blog' && linkId === 'blog') {
            link.classList.add('active');
        }
    });
});