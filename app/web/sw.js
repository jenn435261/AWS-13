// Hand-written offline app-shell service worker for Resilience Network.
//
// Why hand-written: current Flutter emits a flutter_service_worker.js that
// deliberately UNREGISTERS itself (it caches nothing), so it cannot provide an
// offline cold start. This worker fills that gap with an honest, minimal
// cache-first shell so the app boots with no network and loads its LOCAL Drift
// database (sqlite3.wasm + drift_worker.js) from cache.
//
// Strategy:
//  * App shell (index.html, the Flutter bootstrap/runtime, canvaskit, fonts,
//    sqlite3.wasm, drift_worker.js): cache-first, so a cold reload offline
//    still boots.
//  * app-config.json: network-first with a cache fallback, so a reachable
//    cloud can update the runtime config but an offline boot still gets the
//    last-seen config.
//  * Everything else (same-origin GET): stale-while-revalidate.
//
// It NEVER caches the API (/v1/ ... ) — those are live data calls the app
// handles itself (verify-before-store). It only caches the static shell.

const SHELL_CACHE = 'resilience-shell-v1';
const RUNTIME_CACHE = 'resilience-runtime-v1';

// The minimum shell to cold-start. Hashed Flutter assets are added on the fly
// by the runtime cache; these are the stable, known entry points plus the
// local-DB assets the feature explicitly requires to be cached.
const SHELL_ASSETS = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'manifest.json',
  'sqlite3.wasm',
  'drift_worker.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(SHELL_CACHE);
      // Best-effort: a missing optional asset must not fail the whole install.
      await Promise.all(
        SHELL_ASSETS.map((url) =>
          cache.add(new Request(url, { cache: 'reload' })).catch(() => {})
        )
      );
      await self.skipWaiting();
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter((k) => k !== SHELL_CACHE && k !== RUNTIME_CACHE)
          .map((k) => caches.delete(k))
      );
      await self.clients.claim();
    })()
  );
});

function isApi(url) {
  return url.pathname.startsWith('/v1/') || url.pathname.startsWith('/node/');
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return; // only our own shell
  if (isApi(url)) return; // live API, never cached by the shell worker

  // Runtime config: network-first, fall back to cache so an offline boot works.
  if (url.pathname.endsWith('/app-config.json')) {
    event.respondWith(
      (async () => {
        try {
          const fresh = await fetch(req);
          const cache = await caches.open(RUNTIME_CACHE);
          cache.put(req, fresh.clone());
          return fresh;
        } catch (e) {
          const cached = await caches.match(req);
          if (cached) return cached;
          throw e;
        }
      })()
    );
    return;
  }

  // Navigations: serve the cached shell so a cold reload offline still boots.
  if (req.mode === 'navigate') {
    event.respondWith(
      (async () => {
        try {
          return await fetch(req);
        } catch (e) {
          const cache = await caches.open(SHELL_CACHE);
          const shell =
            (await cache.match('index.html')) || (await cache.match('./'));
          if (shell) return shell;
          throw e;
        }
      })()
    );
    return;
  }

  // Everything else same-origin: cache-first with background refresh.
  event.respondWith(
    (async () => {
      const cached = await caches.match(req);
      const network = fetch(req)
        .then((resp) => {
          if (resp && resp.status === 200 && resp.type === 'basic') {
            caches.open(RUNTIME_CACHE).then((c) => c.put(req, resp.clone()));
          }
          return resp;
        })
        .catch(() => cached);
      return cached || network;
    })()
  );
});
