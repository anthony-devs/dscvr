/* DSCVR service worker.
 *
 * - Page navigations and same-origin code (index.html, main.dart.js,
 *   flutter_bootstrap.js, wasm): network first, but if the network hasn't
 *   answered within NETWORK_WAIT_MS and we have a cached copy, open from the
 *   cache. On weak connections even a "nothing changed" check can hang for a
 *   long time, and that made repeat visits as slow as the first. The network
 *   answer still updates the cache, and the page offers a reload when a new
 *   version is ready.
 * - Other same-origin static files (fonts, icons, assets): stale-while-revalidate.
 * - Flutter's CanvasKit on gstatic is versioned by hash: cache first.
 * - Everything else (Firestore, Auth, Cloud Functions, Storage) is never cached.
 *
 * Bump VERSION to force-drop old caches.
 */
const VERSION = 'dscvr-v5';
const NETWORK_WAIT_MS = 2500;
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

function saveBundle(request, res) {
  const copy = res.clone();
  return caches.open(VERSION).then(async (c) => {
    // Each deploy ships main.<hash>.dart.js; drop previous builds' bundles.
    const path = new URL(typeof request === 'string' ? request : request.url, self.location).pathname;
    if (/\/main\.[0-9a-f]+\.dart\.js$/.test(path)) {
      for (const k of await c.keys()) {
        if (k.url !== request.url && /\/main\.[0-9a-f]+\.dart\.js$/.test(new URL(k.url).pathname)) c.delete(k);
      }
    }
    await c.put(request, copy);
  });
}

// Network first, with a deadline: after NETWORK_WAIT_MS, a cached copy wins.
function networkFirst(request, cacheKey, clientId) {
  const key = cacheKey || request;
  return caches.match(key).then((cached) => {
    const network = fetch(new Request(request, { cache: 'no-cache' }))
      .then((res) => {
        if (res && res.ok) {
          if (cached && clientId && /\.(?:m?js|wasm)$/.test(new URL(request.url).pathname) && res.status === 200 &&
              cached.headers.get('etag') && res.headers.get('etag') !== cached.headers.get('etag')) {
            self.clients.get(clientId).then((c) => c && c.postMessage({ type: 'dscvr-downloading-update' }));
          }
          saveBundle(key, res);
        }
        return res;
      });
    if (!cached) return network;
    const timeout = new Promise((resolve) => setTimeout(() => resolve(cached), NETWORK_WAIT_MS));
    return Promise.race([network.catch(() => cached), timeout]);
  });
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  if (req.mode === 'navigate') {
    event.respondWith(networkFirst(req, 'index.html', event.resultingClientId || event.clientId));
    return;
  }

  if (url.origin === self.location.origin) {
    if (url.pathname.endsWith('/sw.js') || url.pathname.endsWith('version.json')) return;
    if (/\.(?:m?js|wasm)$/.test(url.pathname)) {
      event.respondWith(networkFirst(req, null, event.clientId));
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
