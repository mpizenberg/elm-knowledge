# Packages

In this document, we gather some of the most useful packages to enhance your Elm applications.

## Virtual DOM kernel patching with elm-safe-virtual-dom

[elm-safe-virtual-dom](https://github.com/lydell/elm-safe-virtual-dom) provides patched versions
of `elm/virtual-dom`, `elm/html`, and `elm/browser` that fix DOM-related bugs.
It makes Elm apps robust against browser extensions (Grammarly, etc.) and page translators
(Google Translate) that modify the DOM and would otherwise crash the app.
It also fixes the `Html.map` bug. NoRedInk reported going from thousands of virtual DOM errors per day to zero.

Since kernel code cannot be published on package.elm-lang.org, installation requires
copying forked packages into a local `ELM_HOME`. The repo provides a `replace-kernel-packages.mjs`
Node.js script for this. Set `ELM_HOME=elm-stuff/elm-home/` to keep the patched cache project-local.
In practice, add a setup script (e.g. `npm run vdom:patch`) that runs the patching,
then compile with `ELM_HOME=elm-stuff/elm-home/ elm make ...`.

Key breaking change: Elm no longer empties mount elements — only elements marked with `data-elm`
are virtualized, which also enables server-side rendering.

## Extra Core Functions with core-extra

[elmcraft/core-extra](https://github.com/elmcraft/core-extra) extends Elm's standard library
with community-contributed utility functions. It consolidates several previously separate packages
(elm-community extras, cmd-extra, tuple-extra, set-extra, elm-ordering) into a single dependency.

Modules: `Array.Extra`, `Basics.Extra`, `Char.Extra`, `Cmd.Extra`, `Dict.Extra`, `Float.Extra`,
`List.Extra`, `Maybe.Extra`, `Order.Extra`, `Result.Extra`, `Set.Extra`, `String.Extra`,
`Tuple.Extra`, `Triple.Extra`.

## UI with elm-ui

The best UI and design system for Elm is elm-ui.
Matthew Griffith did a tremendous job at making a UI library with the philosophy "if it compiles, layout is correct".
For humans, I highly recommend watching his talk ["Building a Toolkit for Design"](https://youtu.be/Ie-gqwSHQr0?si=Tz4HFLUNBQuwkFxu).

The v2 of elm-ui has been in the works for a while, and lives in [branch `2.0` of the repository](https://github.com/mdgriffith/elm-ui/tree/2.0).
It isn't published as a package yet, so to use it, one needs to embed it in their project and adjust all the dependencies and source directories.
The v2 branch also depends on an unpublished v2 of [elm-animator](https://github.com/mdgriffith/elm-animator/tree/v2), which must be embedded alongside it.

v2 renames `Element` to `Ui`, merges `Background`/`Border` into `Ui`, and adds 7 new modules
(`Ui.Prose`, `Ui.Anim`, `Ui.Gradient`, `Ui.Responsive`, `Ui.Layout`, `Ui.Shadow`, `Ui.Table`).

The core layout model is unchanged: `el`/`row`/`column` with `padding` + `spacing` (no margins),
and sizing via `fill`/`shrink`/`portion n`.

Key v2 additions:

- `Ui.Responsive` — pure CSS breakpoints (no JS flags or subscriptions)
- `Ui.Anim` — built-in transitions, keyframes, and presets (replaces `elm-animator`)
- `Ui.Prose` — paragraphs and semantic lists
- Attribute composition: `noAttr`, `attrs` (batch), `attrIf` (conditional)

Biggest gotchas: `rgb` now takes 0–255 integers (not 0.0–1.0 floats),
and `button`/`link` are attributes rather than elements.

See [examples/elm-ui/elm-ui-v2.md](examples/elm-ui/elm-ui-v2.md) for a full v2 API reference,
and [examples/elm-ui/](examples/elm-ui/) for a working demo.

## Task Ports with elm-concurrent-task

Ports and commands can be limiting because they don't have a composition mechanism.
Each command must be dealt with in the `update` function with a dedicated message.
The package [elm-concurrent-task](https://github.com/andrewMacmurray/elm-concurrent-task) provides an effective alternative.
It enables running a tree of tasks concurrently, and calling JS as tasks.
Setting it up requires installing both the Elm package and the JS package (`@andrewmacmurray/elm-concurrent-task`).

Built-in modules provide drop-in replacements for common `elm/core` and `elm/browser` tasks:

- `ConcurrentTask.Http` — `get`, `post`, `request` (like `elm/http` but composable)
- `ConcurrentTask.Browser.Dom` — `focus`, `blur`, `getElement`, `getViewport`, `setViewport`
- `ConcurrentTask.Time` — `now`, `here`, `getZoneName`, plus `withDuration` for timing tasks
- `ConcurrentTask.Process` — `sleep`, `withTimeout` (cancel a task after N ms)
- `ConcurrentTask.Random` — `generate` from any `Random.Generator`

Define custom tasks with `ConcurrentTask.define { function, expect, errors, args }`.
The `function` string maps to a JS function registered with `ConcurrentTask.register` on the JS side.
JS functions return a value for success or `{ error: ... }` for expected errors.

Composition:

- **Concurrent**: `map2`, `map3`, `batch` run tasks in parallel
- **Sequential**: `andThen` chains tasks where the second depends on the first's result

Wiring requires two ports (`send`, `receive`), a `ConcurrentTask.Pool` stored in the model,
and an `onProgress` subscription. Use `ConcurrentTask.attempt` to start a task — it returns an updated pool and a command.
Handle `OnProgress (pool, cmd)` in update to forward intermediate results.

Good use cases: app initialization that loads multiple resources concurrently (localStorage + HTTP + DOM measurements),
multi-step workflows that would otherwise bounce through `update` (read config → fetch API → write result),
parallel HTTP requests with `batch`, and timed operations with `withDuration`.

Key gotcha: `map2`/`map3` run concurrently (unlike `elm/core` `Task.map2` which is sequential).

See [examples/concurrent-task](examples/concurrent-task/) for a working demo.

## IndexedDB with elm-indexeddb

[elm-indexeddb](https://github.com/mpizenberg/elm-indexeddb) provides IndexedDB support for Elm
via [elm-concurrent-task](#task-ports-with-elm-concurrent-task).
It uses phantom types to enforce key discipline at compile time —
you cannot accidentally call `put` on a `GeneratedKey` store or `insert` on an `InlineKey` store.
Setting it up requires installing both the Elm source and the JS companion (`createTasks()`).

Three store types: `InlineKey` (key extracted from value at a key path),
`ExplicitKey` (key provided on every write), and `GeneratedKey` (auto-incremented by IndexedDB).
Define a schema with a version number (bump to trigger migrations), then `open` it.

All operations return `ConcurrentTask Error` values, so they compose with `andThen`,
run concurrently with `map2`/`batch`, and handle errors uniformly.

See [examples/indexeddb](examples/indexeddb/) for a working demo.

## Progressive Web Apps with elm-pwa

[elm-pwa](https://github.com/mpizenberg/elm-pwa) bridges Elm applications and browser PWA APIs
through a port-based system. It manages service worker lifecycles, installation prompts,
connectivity detection, and push notifications.

Two paired ports (`pwaIn` / `pwaOut`) handle bidirectional communication.
Events (e.g. `ConnectionChanged`, `UpdateAvailable`, `InstallAvailable`, `PushSubscription`)
flow from browser APIs to Elm; commands (`acceptUpdate`, `requestInstall`, `subscribePush`, etc.)
flow from Elm to browser APIs.

The JS companion provides `generateSW()` to create a service worker with built-in caching strategies
(navigation fallback, network-only, network-first, cache-first), and `init()` to wire everything up
including automatic update checks on tab visibility changes.

See the [elm-pwa demo](https://github.com/mpizenberg/elm-pwa/tree/main/examples/demo) for a working example.

## Navigation and URL handling with elm-url-navigation-port

[elm-url-navigation-port](https://github.com/mpizenberg/elm-url-navigation-port) provides port-based SPA
navigation for `Browser.element`. Use it instead of `Browser.application` for better compatibility
with external libraries and browser extensions. Navigation targets use `AppUrl` from
[lydell/elm-app-url](https://github.com/lydell/elm-app-url) — relative URLs, always same-origin.

Setup: install the Elm package and JS companion, declare two ports (`navCmd : Nav.CommandPort msg`,
`onNavEvent : Nav.EventPort msg`), pass `location.href` as a flag for initial routing, and subscribe
with `Nav.onEvent onNavEvent GotNavigationEvent`. The `Nav.Event` record contains `appUrl : AppUrl`
and `state : Decode.Value`.

Five navigation commands: `pushUrl` (standard page navigation), `pushUrlWithState` (page navigation
with a state object, e.g. scroll position), `pushState` (state-only, URL unchanged — for wizards/tabs),
`back`/`forward` (history traversal by N steps), and `replaceUrl` (cosmetic URL update, no history entry,
Elm not notified). Use `preventDefaultOn "click"` on `<a>` tags to intercept link clicks.

## WebSockets with elm-websocket-manager

[elm-websocket-manager](https://github.com/mpizenberg/elm-websocket-manager) provides type-safe WebSocket
management for Elm with automatic reconnection and binary data support.

Setup requires two ports (`wsOut`, `wsIn`) and a JS companion (`import * as wsm from "elm-websocket-manager"; wsm.init({ wsOut: app.ports.wsOut, wsIn: app.ports.wsIn });`).

Send text with `WS.sendString`, binary with `WS.sendBytes`. Binary data uses an XHR monkeypatch
to transfer `Bytes` through ports with zero JSON overhead.

Handle events by pattern matching on `WS.Event`:

```elm
case event of
    WS.Opened                  -> -- connected
    WS.MessageReceived data    -> -- text message
    WS.BinaryReceived bytes    -> -- binary message (Bytes)
    WS.Closed info             -> -- closed {code, reason, wasClean}
    WS.Reconnecting info       -> -- {attempt, nextDelayMs, maxRetries}
    WS.Reconnected             -> -- back online after reconnection
    WS.ReconnectFailed         -> -- gave up reconnecting
    WS.Error message           -> -- error
    WS.NoOp                    -> ( model, Cmd.none )
```

See the [example/](https://github.com/mpizenberg/elm-websocket-manager/tree/main/example) directory
for a runnable echo client with text and binary messaging, connection state UI, and reconnection.

## Languages i18n with travelm-agency

[travelm-agency](https://github.com/anmolitor/travelm-agency) is a compile-time i18n solution for Elm.
Translation files (JSON, Properties, or Fluent) are processed into a strongly-typed Elm module
with one function per translation key. Placeholder requirements are enforced at compile time.

In **inline mode**, all translations are embedded in the generated Elm code (no HTTP needed).
In **dynamic mode**, translations are loaded at runtime from optimized JSON files.

Key patterns:

- Detect language from `navigator.languages` by iterating and calling `languageFromString` on each tag
- Switch language by reinitializing `I18n` (inline) or via `switchLanguage` (dynamic)
- Keep `document.documentElement.lang` in sync via a port

See [examples/i18n](examples/i18n/) for a working demo (inline mode).

## Big Integers with elm-integer

Elm's `Int` overflows at 21! (exceeds `2^53 - 1`). For crypto, financial math, or computing large factorials,
use [dwayne/elm-natural](https://github.com/dwayne/elm-natural) (non-negative) or [dwayne/elm-integer](https://github.com/dwayne/elm-integer) (signed).

Key API:

- Create: `Natural.fromString` (supports `0b`, `0o`, `0x` prefixes), `Natural.fromSafeInt` (for constants)
- Arithmetic: `add`, `mul`, `sub` (saturating), `divModBy`, `exp`
- Display: `toString`, `toHexString`, `toBinaryString`, `toOctalString`

Gotchas:

- `Natural.sub a b` returns `zero` when `b > a` (saturating subtraction)
- `Natural.toInt` wraps: returns `n mod (maxSafeInt + 1)` for large values
- Equality `==` works on `Natural` (unlike `AnyDict`)

See [examples/big-integers](examples/big-integers/) for a working demo.

## Markdown Parsing with elm-markdown

[dillonkearns/elm-markdown](https://github.com/dillonkearns/elm-markdown) parses markdown in a two-step pipeline:
`Markdown.Parser.parse` turns raw text into `Block` values, then `Markdown.Renderer.render` converts those blocks
into any output type using a `Renderer` record.

The `Renderer` record has one field per markdown element (heading, paragraph, codeBlock, link, etc.).
Start from `defaultHtmlRenderer` and override the fields you want to customize — e.g. add `id` attributes
to headings for anchor links.

Custom HTML tags (e.g. `<callout type="info">`) are supported via `Markdown.Html.oneOf` + `Markdown.Html.tag`,
using a decoder-style API where `withAttribute` / `withOptionalAttribute` extract tag attributes.

Key gotcha: `defaultHtmlRenderer` rejects all HTML tags by default. If your markdown contains any HTML,
you must provide a custom `html` handler listing every tag you want to support, or rendering will fail.

See [examples/markdown](examples/markdown/) for a working demo.

## Remote Data state with remotedata

The common pattern `{ data : Maybe a, loading : Bool, error : Maybe String }` allows invalid states
(e.g. `loading = True` with `error = Just "..."`). [krisajenkins/remotedata](https://github.com/krisajenkins/remotedata)
replaces this with a single union type:

```elm
type RemoteData e a = NotAsked | Loading | Failure e | Success a
```

`WebData a` is an alias for `RemoteData Http.Error a`.

Key pattern for HTTP integration:

```elm
Http.expectJson (RemoteData.fromResult >> GotPosts) decoder
```

This converts `Result Http.Error a` into `WebData a` in one line.
Pattern match exhaustively on all 4 variants in the view to ensure every state is handled.

See [examples/remote-data](examples/remote-data/) for a working demo.

## Dicts of custom keys with any-dict

Elm's `Dict` only accepts `comparable` keys (Int, String, etc.). To use a custom type as a key,
[turboMaCk/any-dict](https://github.com/turboMaCk/any-dict) lets you provide a `k -> comparable` function:

```elm
type Fruit = Apple | Banana | Orange
inventory : AnyDict String Fruit Int
inventory = Dict.Any.empty fruitToString
```

Key patterns:

- Create: `Dict.Any.empty toComparable`, `Dict.Any.fromList toComparable pairs`
- Query/modify: `get`, `insert`, `update`, `remove` — same API as `Dict`

Gotchas:

- `toComparable` is provided once at creation; all operations use the stored function
- `toComparable` must be injective (every distinct key must produce a different comparable)
- Don't use `==` to compare `AnyDict` values (causes runtime exception). Use `Dict.Any.equal` instead

See [examples/any-dict](examples/any-dict/) for a working demo.

## Consistent forms with elm-form

[dwayne/elm-form](https://github.com/dwayne/elm-form) is a small (~200 lines), UI-agnostic form library
that decouples form state, validation, and field access from rendering. It works with elm-ui, elm-css,
plain HTML, or any view layer. Its companion packages `dwayne/elm-field` (typed fields with parsing,
trimming, dirty tracking) and `dwayne/elm-validation` (error-accumulating applicative) provide the
field and validation primitives.

A form is defined by four things: a **State** record of `Field` values, an **Accessors** record
of `{ get, modify }` pairs, a custom **Error** union type, and a **validate** function that produces
a typed **Output** via an applicative pipeline.

Key patterns:

- `Form.get .field form` / `Form.modify .field f form` — read and update fields
- `Form.isInvalid form` / `Form.validateAsMaybe form` — check validity and extract output
- `Form.List` — dynamic collections of sub-forms (add/remove) with `Form.List.validate`
- `Field.isDirty` — show errors only after user interaction
- `V.andThen` — conditional/branching validation (e.g. different fields per format selection)
- Non-`Field` values in state (e.g. `TitleStatus`) with their own accessors for integrating
  async/remote validation results into the validation function

See [examples/forms/README.md](examples/forms/README.md) for a working demo covering custom field types, dynamic
speaker lists, format-dependent branching, and simulated remote title uniqueness checking.
See [reports/forms.md](reports/forms.md) for a detailed comparison of many Elm form packages.

## Cardano Interop with elm-cardano

https://github.com/elm-cardano/elm-cardano
