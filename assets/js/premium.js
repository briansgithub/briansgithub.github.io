/* ============================================
   PREMIUM.JS — bellsworth.info
   Particles, mobile menu, scroll animations
   ============================================ */

(function () {
  'use strict';

  // --- Mobile hamburger toggle ---
  const toggle = document.querySelector('.nav-toggle');
  const navLinks = document.querySelector('.nav-links');
  if (toggle && navLinks) {
    toggle.addEventListener('click', function () {
      navLinks.classList.toggle('open');
    });
    // Close menu on link click
    navLinks.querySelectorAll('a').forEach(function (link) {
      link.addEventListener('click', function () {
        navLinks.classList.remove('open');
      });
    });
  }

  // --- Scroll-triggered fade-in ---
  var fadeEls = document.querySelectorAll('.fade-in');
  if (fadeEls.length && 'IntersectionObserver' in window) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12 });
    fadeEls.forEach(function (el) { observer.observe(el); });
  } else {
    // Fallback: show all
    fadeEls.forEach(function (el) { el.classList.add('visible'); });
  }

  // --- Active nav link ---
  var currentPath = window.location.pathname.replace(/\/$/, '') || '/';
  var navAnchors = document.querySelectorAll('.nav-links a');
  navAnchors.forEach(function (a) {
    var href = a.getAttribute('href');
    if (!href) return;
    // Normalize
    if (href === 'index.html' || href === './') href = '/';
    var linkPath = href.replace(/\/$/, '') || '/';
    if (currentPath.endsWith(linkPath) || (linkPath === '/' && (currentPath === '/' || currentPath.endsWith('/index.html')))) {
      a.classList.add('active');
    }
  });

  // --- Particle canvas (only on homepage) ---
  var canvas = document.getElementById('particle-canvas');
  if (!canvas) return;
  var ctx = canvas.getContext('2d');
  var particles = [];
  var particleCount = 60;

  function resize() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  }
  resize();
  window.addEventListener('resize', resize);

  function Particle() {
    this.x = Math.random() * canvas.width;
    this.y = Math.random() * canvas.height;
    this.vx = (Math.random() - 0.5) * 0.4;
    this.vy = (Math.random() - 0.5) * 0.4;
    this.r = Math.random() * 1.8 + 0.5;
    this.alpha = Math.random() * 0.4 + 0.1;
  }

  for (var i = 0; i < particleCount; i++) {
    particles.push(new Particle());
  }

  function drawParticles() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      p.x += p.vx;
      p.y += p.vy;
      if (p.x < 0) p.x = canvas.width;
      if (p.x > canvas.width) p.x = 0;
      if (p.y < 0) p.y = canvas.height;
      if (p.y > canvas.height) p.y = 0;

      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(34, 211, 238, ' + p.alpha + ')';
      ctx.fill();

      // Draw lines between nearby particles
      for (var j = i + 1; j < particles.length; j++) {
        var p2 = particles[j];
        var dx = p.x - p2.x;
        var dy = p.y - p2.y;
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < 150) {
          ctx.beginPath();
          ctx.moveTo(p.x, p.y);
          ctx.lineTo(p2.x, p2.y);
          ctx.strokeStyle = 'rgba(34, 211, 238, ' + (0.06 * (1 - dist / 150)) + ')';
          ctx.lineWidth = 0.5;
          ctx.stroke();
        }
      }
    }
    requestAnimationFrame(drawParticles);
  }
  drawParticles();
})();
