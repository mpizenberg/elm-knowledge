var CACHE_NAME = "elm-pwa-v1";
var PRECACHE_URLS = ["/", "/elm.js", "/style.css", "/manifest.webmanifest"];

// Install: cache the app shell
self.addEventListener("install", function (event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function (cache) {
      return cache.addAll(PRECACHE_URLS);
    }),
  );
});

// Activate: clean up old caches
self.addEventListener("activate", function (event) {
  event.waitUntil(
    caches.keys().then(function (names) {
      return Promise.all(
        names
          .filter(function (n) {
            return n !== CACHE_NAME;
          })
          .map(function (n) {
            return caches.delete(n);
          }),
      );
    }),
  );
});

// Fetch: cache-first for static assets, network-first for API calls
self.addEventListener("fetch", function (event) {
  var url = new URL(event.request.url);

  // For navigation requests, always serve the cached app shell
  // (Elm handles routing client-side)
  if (event.request.mode === "navigate") {
    event.respondWith(
      caches.match("/").then(function (cached) {
        return cached || fetch(event.request);
      }),
    );
    return;
  }

  // For API calls (e.g., /api/*), use network-first
  if (url.pathname.startsWith("/api/")) {
    event.respondWith(
      fetch(event.request)
        .then(function (response) {
          // Cache a clone of the response
          var clone = response.clone();
          caches.open(CACHE_NAME).then(function (cache) {
            cache.put(event.request, clone);
          });
          return response;
        })
        .catch(function () {
          return caches.match(event.request);
        }),
    );
    return;
  }

  // For everything else, use cache-first
  event.respondWith(
    caches.match(event.request).then(function (cached) {
      return cached || fetch(event.request);
    }),
  );
});

// Only skip waiting when explicitly told to by the client
self.addEventListener("message", function (event) {
  if (event.data && event.data.type === "SKIP_WAITING") {
    self.skipWaiting();
  }
});
