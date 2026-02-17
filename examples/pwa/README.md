# Progressive Web App with Elm

This example demonstrates how to build a PWA with Elm, covering service worker registration, offline caching, install prompt handling, and update notifications -- all connected to Elm via ports.

## How it works

PWA features live entirely in JavaScript and the browser -- Elm participates through ports.

### Ports (JS -> Elm)

- **`onConnectionChange`**: sends `Bool` when the device goes online or offline
- **`onNewVersionAvailable`**: fires when a new service worker is installed and waiting
- **`onInstallAvailable`**: fires when the browser's `beforeinstallprompt` event occurs (Chromium only)
- **`onInstalled`**: fires when the `appinstalled` event occurs

### Ports (Elm -> JS)

- **`acceptUpdate`**: tells the waiting service worker to `skipWaiting`, triggering a page reload with the new version
- **`requestInstall`**: triggers the deferred browser install prompt

### Service worker strategy

The hand-written `sw.js` (~70 lines) uses:

- **Cache First** for static assets (elm.js, style.css, index.html)
- **Network First** for API calls (`/api/*`) with cache fallback
- **Navigation fallback** to the cached `/` for all page navigations (SPA routing)
- **Manual skip-waiting** so users control when the update activates

On each deploy, bump `CACHE_NAME` in `sw.js` (e.g., `"elm-pwa-v2"`) to trigger the update flow and purge old caches.

### SPA update checking

Since Elm SPAs rarely do full page navigations, the browser won't automatically check for service worker updates. The JS code handles this by:

1. Polling `registration.update()` every hour
2. Checking on `visibilitychange` (when the user returns to the tab)

## Key patterns

- **No Workbox needed**: Elm compiles to a single JS file, making the caching profile simple enough for a hand-written service worker
- **Update flow**: new SW installs in the background -> Elm shows a banner -> user clicks "Update now" -> `skipWaiting` -> `controllerchange` -> page reload
- **`navigator.onLine` is unreliable**: it only detects network connectivity, not internet reachability. Use it as a hint, not a guarantee
- **Icons**: use opaque (non-transparent) icons -- iOS and Android fill transparency with an uncontrollable background color

## Running the example

```sh
elm make src/Main.elm --output=static/elm.js
```

Then serve the `static/` directory with any HTTP server:

```sh
cd static
python -m http.server 8000
```

Open `http://localhost:8000` in your browser.

To test offline behavior: open DevTools > Application > Service Workers, then check "Offline" and reload.

To test the install prompt: use Chrome/Edge (Chromium) and access via `localhost` or HTTPS.

## Project structure

```
pwa/
  pwa.md                    -- PWA detailed information
  elm.json                  -- Elm dependencies (elm/browser, elm/json)
  src/Main.elm              -- Elm app: ports, model, update, views
  static/
    index.html              -- HTML shell: SW registration, port wiring
    sw.js                   -- Hand-written service worker (~70 lines)
    manifest.webmanifest    -- Web app manifest for installability
    style.css               -- App styles
    elm.js                  -- compiled Elm output (generated)
    icons/
      icon-192.svg          -- App icon (192x192)
      icon-512.svg          -- App icon (512x512)
```
