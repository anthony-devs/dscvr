/* DSCVR service worker.
 *
 * - Page navigations: network first, falling back to the cached app shell so
 *   the PWA opens offline.
 * - Same-origin static files (main.dart.js, fonts, icons, canvaskit):
 *   stale-while-revalidate, so updates land on the next launch.
 * - Flutter's CanvasKit on gstatic is versioned by hash: cache first.
 * - Everything else (Firestore, Auth, Cloud Functions, Storage) is never cached.
 *
 * Bump VERSION to force-drop old caches.
 */
const VERSION = 'dscvr-v1';
const SHELL = ['./', 'index.html', 'flutter_bootstrap.js', 'main.dart.js', 'manifest.json', 'favicon.png', 'icons/Icon-192.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(VERSION).then((cache) => cache.addAll(SHELL).catch(() => {})).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

function staleWhileRevalidate(request) {
  return caches.open(VERSION).then((cache) =>
    cache.match(request).then((cached) => {
      const network = fetch(request)
        .then((res) => {
          if (res && res.ok) cache.put(request, res.clone());
          return res;
        })
        .catch(() => cached);
      return cached || network;
    })
  );
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(VERSION).then((c) => c.put('index.html', copy));
          return res;
        })
        .catch(() => caches.match('index.html'))
    );
    return;
  }

  if (url.origin === self.location.origin) {
    if (url.pathname.endsWith('/sw.js') || url.pathname.endsWith('version.json')) return;
    event.respondWith(staleWhileRevalidate(req));
    return;
  }

  if (url.hostname === 'www.gstatic.com' && url.pathname.startsWith('/flutter-canvaskit/')) {
    event.respondWith(
      caches.match(req).then((hit) => hit || fetch(req).then((res) => {
        const copy = res.clone();
        caches.open(VERSION).then((c) => c.put(req, copy));
        return res;
      }))
    );
  }
});
