# Port-based Navigation with Browser.element

This example demonstrates SPA-style navigation in Elm using `Browser.element` and ports, instead of `Browser.application`. This approach works in contexts where `Browser.application` is not available or not desired (e.g., embedded Elm apps, micro-frontends).

## How it works

All navigation goes through two ports:

- **`navigationOut`** (Elm -> JS): Elm sends tagged JSON to request navigation actions.
- **`onNavigation`** (JS -> Elm): JS sends `{href, state}` back to Elm after navigation occurs.

The JS side calls `history.pushState` / `history.replaceState` and listens for `popstate` events. This keeps Elm in control of routing logic while JS handles the browser history API.

## Three navigation patterns

### 1. Page navigation via `pushState` (Home, Wizard, About links)

Standard SPA navigation. Clicking a nav link sends `{tag: "pushUrl", url: "/about"}` through `navigationOut`. JS calls `pushState` and echoes the new URL back to Elm via `onNavigation`. The browser back button works because `popstate` fires and sends the URL to Elm.

### 2. Wizard steps via `pushState` with state object

The wizard uses `history.pushState` with a state object (`{wizardStep: 2}`) but **keeps the URL unchanged** at `/wizard`. This gives back-button support between wizard steps without polluting the URL.

When the user presses Back, the `popstate` event delivers the state object, and Elm uses it to determine which step to show. The URL and state arrive atomically in a single `onNavigation` message, avoiding flash/flicker.

Data flow:
1. User clicks "Next" on Step 1
2. Elm sends `{tag: "pushState", state: {wizardStep: 2}}`
3. JS calls `pushState({wizardStep: 2}, "")` -- URL stays `/wizard`
4. JS echoes `{href: "/wizard", state: {wizardStep: 2}}` to Elm
5. Elm decodes the state and shows Step 2
6. Pressing Back triggers `popstate` with `state: null` -> Elm shows Step 1
7. Pressing Back again triggers `popstate` with `href: "/"` -> Elm shows Home

### 3. Cosmetic URL updates via `replaceState` (About counter)

The About page has a counter with a "+1" button. Each click increments `model.counter` and calls `replaceState` to update the URL to `/about#3`, but **does not notify Elm**. The model is the source of truth -- the URL is updated purely for display and shareability.

This demonstrates that `replaceState` can update the URL bar without creating a new history entry and without triggering any Elm update cycle.

## Running the example

```sh
elm make src/Main.elm --output=static/elm.js
```

Then serve the `static/` directory with any HTTP server, e.g.:

```sh
cd static
python3 -m http.server 8000
```

Open `http://localhost:8000` in your browser.

## Project structure

```
navigation/
  elm.json          -- Elm dependencies (elm/browser, elm/url, lydell/elm-app-url)
  src/Main.elm      -- Elm app: ports, routing, model, update, views
  static/
    index.html      -- HTML shell with JS port wiring
    elm.js          -- compiled Elm output (generated)
```
