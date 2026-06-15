/**
 * Frontier Flat Rate — Privacy-First Analytics
 * Provider: Counter.dev (free, no cookies, GDPR-compliant)
 * 
 * SETUP (30 seconds):
 * 1. Go to https://counter.dev/ — sign up with email
 * 2. Add your site: maltbae.github.io/frontier-flat-rate
 * 3. Copy your data-id from the dashboard
 * 4. Replace PLACEHOLDER_YOUR_COUNTER_DEV_ID below
 * 5. Push to GitHub — analytics active immediately
 */
(function() {
  var siteId = 'PLACEHOLDER_YOUR_COUNTER_DEV_ID';
  if (siteId.indexOf('PLACEHOLDER') !== -1) {
    // Not configured yet — silent no-op
    if (typeof console !== 'undefined' && console.log) {
      console.log('[analytics] Counter.dev not configured. See scripts/analytics.js for setup.');
    }
    return;
  }
  var s = document.createElement('script');
  s.src = 'https://cdn.counter.dev/script.js';
  s.setAttribute('data-id', siteId);
  document.head.appendChild(s);
})();
