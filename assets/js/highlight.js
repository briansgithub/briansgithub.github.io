// JavaScript to highlight the current menu item
document.addEventListener("DOMContentLoaded", function() {
    // Get the current URL path
    const currentPath = window.location.pathname;

    const currentUrl = window.location.href;
    // Extract the filename from the URL path
    const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1);
    // Split the URL path into segments and Extract the parent directory from the URL path
    const pathSegments = currentPath.split('/');
    const parentDirectory = pathSegments.length > 2 ? pathSegments[pathSegments.length - 2] : '';

    // Get all the menu items
    const menuItems = document.querySelectorAll('#menu ul li a');

    // Loop through each menu item
    menuItems.forEach(function(menuItem) {
        // Create an anchor element to parse the href
        const tempAnchor = document.createElement('a');
        tempAnchor.href = menuItem.href;

        // Check if the current URL path matches the href of the menu item
        if (tempAnchor.pathname === currentPath 
            || 
            (menuItem.href === "https://bellsworth.info/" && 
                (currentPath === "/" 
                || currentPath === "/index.html"
                || currentUrl === "https://bellsworth.info/")
            )
        ) 
        {
            // Manually trigger hover styles by adding the necessary styles
            menuItem.style.borderBottomColor = '#0000D0';
            menuItem.style.color = '#000';
            menuItem.style.backgroundColor = '#B8B8B8';
        }
    });
});

/*

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

*/