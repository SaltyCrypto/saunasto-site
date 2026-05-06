/* Atika Landing Pages
 * Progressive enhancement: pages work fully without JS.
 * JS adds: count-up stat animation, scroll-triggered pin drops,
 *         live waitlist counter, smooth interactions.
 *
 * Zero dependencies. ~3KB minified. Respects prefers-reduced-motion.
 */

(function () {
  'use strict';

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ============================
   * Count-up animation
   * Animates a number from 0 to its target value on scroll-into-view.
   * Preserves original formatting (commas, dots, plus signs, percent).
   * ============================ */
  function animateCountUp(el, duration) {
    if (reduceMotion || el.dataset.animated) return;
    el.dataset.animated = 'true';

    const original = el.textContent.trim();
    // Parse: extract digits, remember separators and suffixes
    const match = original.match(/^([\d,\.\s]+)(.*)$/);
    if (!match) return;

    const numStr = match[1];
    const suffix = match[2] || '';
    const rawNum = parseFloat(numStr.replace(/[,\.\s]/g, ''));
    if (isNaN(rawNum) || rawNum < 1) return;

    // Detect locale: if the original used . as thousands separator (Greek format),
    // preserve it. Otherwise use , (English/Hebrew).
    const usesDotThousands = /\d\.\d{3}(?!\d)/.test(numStr);
    const formatNum = (n) => {
      const formatted = Math.floor(n).toLocaleString(usesDotThousands ? 'de-DE' : 'en-US');
      return formatted + suffix;
    };

    const start = performance.now();
    const totalDuration = duration || 1400;

    function step(now) {
      const progress = Math.min((now - start) / totalDuration, 1);
      // Ease-out cubic
      const eased = 1 - Math.pow(1 - progress, 3);
      const current = rawNum * eased;
      el.textContent = formatNum(current);
      if (progress < 1) {
        requestAnimationFrame(step);
      } else {
        el.textContent = original; // restore exact original
      }
    }
    requestAnimationFrame(step);
  }

  /* ============================
   * Scroll-triggered animations via IntersectionObserver
   * ============================ */
  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return;
        const target = entry.target;
        target.classList.add('in-view');

        // Hero stat count-up
        if (target.classList.contains('hero-stat-value')) {
          animateCountUp(target);
        }

        // Density-pin: defer the CSS animation until scrolled into view
        if (target.classList.contains('density-svg')) {
          target.classList.add('animate-pins');
        }

        observer.unobserve(target);
      });
    }, { threshold: 0.25, rootMargin: '0px 0px -50px 0px' });

    document.querySelectorAll('.hero-stat-value, .density-svg').forEach(el => observer.observe(el));
  } else {
    // Fallback for very old browsers: trigger animations on load
    document.querySelectorAll('.hero-stat-value').forEach(animateCountUp);
    document.querySelectorAll('.density-svg').forEach(el => el.classList.add('animate-pins'));
  }

  /* ============================
   * Live waitlist counter
   * Reads a static JSON endpoint that you maintain (or proxy from Formspree/Buttondown).
   * Endpoint shape: { "greece": 237, "israel": 184, "italy": 0, "max": 500 }
   *
   * Fallback: if endpoint is unreachable, the static "237 / 500" copy stays.
   * ============================ */
  async function refreshWaitlistCounter() {
    const country = document.body.dataset.country;
    if (!country) return;

    const counter = document.querySelector('.waitlist-counter');
    if (!counter) return;

    try {
      const res = await fetch('/api/waitlist.json', { cache: 'no-store' });
      if (!res.ok) return;
      const data = await res.json();
      const count = data[country];
      const max = data.max || 500;
      if (typeof count !== 'number') return;

      // Update the strong elements only, preserve surrounding text
      const strongs = counter.querySelectorAll('strong');
      if (strongs.length >= 2) {
        strongs[0].textContent = count.toLocaleString();
        strongs[1].textContent = max.toLocaleString();
      }
    } catch (e) {
      // Silent fail: static content remains visible
    }
  }
  refreshWaitlistCounter();

  /* ============================
   * Smooth scrolling for anchor links
   * (Honors prefers-reduced-motion via CSS already)
   * ============================ */
  document.querySelectorAll('a[href^="#"]').forEach(link => {
    link.addEventListener('click', (e) => {
      const id = link.getAttribute('href').slice(1);
      if (!id) return;
      const target = document.getElementById(id);
      if (!target) return;
      e.preventDefault();
      target.scrollIntoView({
        behavior: reduceMotion ? 'auto' : 'smooth',
        block: 'start'
      });
      // Focus the target for accessibility
      target.setAttribute('tabindex', '-1');
      target.focus({ preventScroll: true });
    });
  });

  /* ============================
   * Waitlist form submission (progressive enhancement)
   * Posts to Kit via fetch, shows inline success without leaving atika.app.
   * Falls back to a standard form POST (which redirects to Kit's hosted
   * confirmation page) if fetch fails or JS is disabled entirely.
   * ============================ */
  document.querySelectorAll('.waitlist-form').forEach(form => {
    form.addEventListener('submit', async (e) => {
      // Honeypot: any value in _gotcha means it's a bot. Silently swallow.
      const honeypot = form.querySelector('input[name="_gotcha"]');
      if (honeypot && honeypot.value) {
        e.preventDefault();
        return;
      }

      // Skip enhancement if action is still a placeholder
      if (form.action.includes('YOUR_FORM_ID')) return;

      e.preventDefault();
      const button = form.querySelector('button[type="submit"]');
      const originalLabel = button.textContent;
      button.disabled = true;
      button.textContent = '...';

      try {
        const res = await fetch(form.action, {
          method: 'POST',
          body: new FormData(form),
          headers: { 'Accept': 'application/json' }
        });
        // Kit returns 200 on accept, may also redirect (opaque-redirect with no-cors).
        // Treat any non-network-error as success; subscriber gets a confirmation email.
        if (res.ok || res.type === 'opaqueredirect') {
          showWaitlistSuccess(form);
        } else {
          throw new Error('HTTP ' + res.status);
        }
      } catch (err) {
        // Re-enable so user can retry; if they retry, we'll let the native
        // form action take over (which goes to Kit's hosted confirmation page).
        button.disabled = false;
        button.textContent = originalLabel;
        // One automatic fallback: native submit (does NOT recurse into this handler).
        form.removeEventListener('submit', arguments.callee);
        form.submit();
      }
    });
  });

  function showWaitlistSuccess(form) {
    const successMsg = form.dataset.success || "You're on the list. Check your inbox to confirm.";
    const section = form.closest('.waitlist') || form.parentElement;
    // Build the success block
    const success = document.createElement('div');
    success.className = 'waitlist-success';
    success.setAttribute('role', 'status');
    success.setAttribute('aria-live', 'polite');
    success.textContent = successMsg;
    // Hide form + finetext, show success
    form.style.display = 'none';
    const finetext = section.querySelector('.waitlist-fineprint');
    if (finetext) finetext.style.display = 'none';
    section.appendChild(success);
    // Move focus for screen readers
    success.setAttribute('tabindex', '-1');
    success.focus({ preventScroll: true });
  }

})();
