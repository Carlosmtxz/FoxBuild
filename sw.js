// Minimal service worker — clears all caches, no offline caching
self.addEventListener('install', e => { self.skipWaiting(); });
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});
// No fetch handler — every request goes straight to the network
