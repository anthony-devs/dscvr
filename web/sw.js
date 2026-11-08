/* DSCVR service worker.
 *
 * - Page navigations: network first, falling back to the cached app shell so
 *   the PWA opens offline.
 * - Same-origin code (main.dart.js, flutter_bootstrap.js, wasm): network first
 *   (revalidated, so a new deploy is picked up immediately), cache when offline.
 * - Other same-origin static files (fonts, icons, assets): stale-while-revalidate.
 * - Flutter's CanvasKit on gstatic is versioned by hash: cache first.
 * - Everything else (Firestore, Auth, Cloud Functions, Storage) is never cached.
 *
 * Bump VERSION to force-drop old caches.
 */
const VERSION = 'dscvr-v4';
const SHELL = ['./', 'index.html', 'flutter_bootstrap.js', 'manifest.json', 'favicon.png?v=2', 'favicon.svg?v=2', 'icons/Icon-192.png?v=2'];

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

function networkFirst(request) {
  // `no-cache` makes the browser revalidate (cheap 304) instead of trusting HTTP cache.
  return fetch(new Request(request, { cache: 'no-cache' }))
    .then((res) => {
      if (res && res.ok) {
        const copy = res.clone();
        caches.open(VERSION).then(async (c) => {
          // Each deploy ships main.<hash>.dart.js; drop previous builds' bundles.
          if (/\/main\.[0-9a-f]+\.dart\.js$/.test(new URL(request.url).pathname)) {
            for (const k of await c.keys()) {
              if (k.url !== request.url && /\/main\.[0-9a-f]+\.dart\.js$/.test(new URL(k.url).pathname)) c.delete(k);
            }
          }
          c.put(request, copy);
        });
      }
      return res;
    })
    .catch(() => caches.match(request));
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
    if (/\.(?:m?js|wasm)$/.test(url.pathname)) {
      event.respondWith(networkFirst(req));
      return;
    }
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
