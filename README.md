# Elm Knowledge

This repository aims to provide a knowledge base to develop Elm applications.
It contains both generic information, and some of my preferences.

## Architecture

- Modules focused on a data structure
- Always expose the minimum required api from modules
- Avoid `Browser.Application` as a main, and prefer `Browser.Element` with routing handled via ports

## Design Patterns

- Extensible record phantom builder pattern (https://www.youtube.com/watch?v=Trp3tmpMb-o)
- https://sporto.github.io/elm-patterns/index.html
- Send bytes through a port: https://github.com/lue-bird/elm-bytes-ports-benchmark
- XHRHttpRequest monkeypatch to send bytes at zero cost: https://github.com/mpizenberg/elm-http-monkeys

## Some GOATs 🐐

These are the GitHub handles of some Elm developers (or orgs) that IMO have greatly contributed to the Elm community and impacted how I write Elm code, and the tools I use.
In no particular order:

evancz, wolfadex, miniBill, lydell, jfmengels, dillonkearns, lue-bird, mdgriffith, dmy, andrewMacmurray, zwilias, avh4, rtfeldman, supermario, MartinSStewart, janiczek, dwayne, jxxcarlson, krisajenkins, ryannhg, robinhegan, ianmackenzie, ...

## Tooling

### Tooling Installation with elm-tooling-cli

[elm-tooling-cli](https://github.com/elm-tooling/elm-tooling-cli) manages Elm tool versions
(elm, elm-format, elm-json, elm-test-rs) via an `elm-tooling.json` file,
as a faster and more secure drop-in replacement for installing them through npm.

Setup: `npx elm-tooling init` generates the config, `npx elm-tooling install` fetches the tools.
Add `"postinstall": "elm-tooling install"` to `package.json` scripts so tools are installed
automatically on `npm install`.

### CI with elm-tooling-action

[elm-tooling-action](https://github.com/mpizenberg/elm-tooling-action) is a GitHub Action
that installs Elm tools (elm, elm-format, elm-json, elm-test-rs) from `elm-tooling.json`
and caches `ELM_HOME` — no npm or package.json required.

```yaml
- uses: mpizenberg/elm-tooling-action@v1.7
  with:
    cache-key: elm-home-${{ hashFiles('elm-tooling.json', 'elm.json') }}
```

Tip: run the action on your main branch first to seed the cache, since GitHub Actions
caches are only accessible from the current branch, parent branches, or the main branch.

### Update dependencies with elm-json

[elm-json](https://github.com/zwilias/elm-json) is a CLI tool for managing Elm dependencies.
Key commands: `elm-json install elm/http` (or `elm/http@2` for a major version),
`elm-json uninstall elm/html`, `elm-json upgrade` (patch/minor only; `--unsafe` allows major bumps),
and `elm-json tree` to visualize the dependency graph.

For applications it pins exact versions and resolves indirect deps;
for packages it sets version ranges. Note: `upgrade` only works for applications, not packages.

### Publish elm packages with elm-publish-action

[elm-publish-action](https://github.com/dillonkearns/elm-publish-action) is a GitHub Action
that automatically publishes your Elm package when the `elm.json` version is unpublished
and CI passes on `main`/`master`. It creates the Git tag and runs `elm publish` for you.

```yaml
- uses: dillonkearns/elm-publish-action@v2
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    path-to-elm: ./node_modules/.bin/elm
```

Workflow: run `elm bump` on a branch, merge to main, CI publishes automatically.
Use `dry-run: true` (without `github-token`) to test without publishing.

Gotcha: the first release (1.0.0) must be published manually with `elm publish` — the action
skips packages that have never been published.

### Code Formatting with elm-format

[elm-format](https://github.com/avh4/elm-format) formats Elm source code according to a standard
set of rules based on the official Elm Style Guide. Run `elm-format .` (or `elm-format Main.elm --yes`)
to format files. Most editors support format-on-save integration.

### Linting with elm-review

[elm-review](https://github.com/jfmengels/node-elm-review) is a static analysis tool for Elm.
It ships with no built-in rules — you configure them in a `review/` directory
(`ReviewConfig.elm` + `elm.json`) by installing rule packages (e.g. `jfmengels/elm-review-unused`).

Key commands: `elm-review init` scaffolds the config, `elm-review` analyzes the project,
`elm-review --fix` offers automatic fixes.
Quick test without setup: `npx elm-review --template jfmengels/elm-review-unused/example`.

### Hot Reload with elm-watch

[elm-watch](https://github.com/lydell/elm-watch) watches Elm source files, recompiles on change,
and hot-reloads the browser while preserving application state.
It intentionally only handles Elm compilation — pair it with your own CSS tools, JS bundler
(esbuild, Vite, etc.), and a process orchestrator like [run-pty](https://github.com/lydell/run-pty).

Configure targets in `elm-watch.json`:

```json
{
  "targets": {
    "My app": {
      "inputs": ["src/Main.elm"],
      "output": "build/main.js"
    }
  }
}
```

Two modes: `elm-watch make` (one-shot, supports `--optimize`) and `elm-watch hot`
(persistent watcher with a browser UI for status, errors, and toggling debug/standard/optimize
per target). The compiled JS must be loaded via a `<script>` tag (not `import`) since
elm-watch relies on the `window.Elm` global.

Hot reloading is ~90% reliable: `view` changes are always safe, but `Model`/`Msg` type changes
can occasionally slip through undetected — elm-watch catches the resulting runtime error
and falls back to a full page reload.

Optional `postprocess` field runs a transform on the output JS (e.g. string replacements
in dev, minification in optimize mode). Use `elm-watch-node` for fast in-process execution
instead of spawning an external command.

### Local Docs with elm-doc-preview

[elm-doc-preview](https://github.com/dmy/elm-doc-preview) is an offline documentation previewer
for Elm packages and applications, with hot reloading. Run `elm-doc-preview` (or `edp`) from
your project directory. For applications, create an `elm-application.json` specifying
`exposed-modules`, `name`, `summary`, and `version`.

### Local packages development

The Elm compiler hard-codes `package.elm-lang.org` as the sole registry
and has no built-in mechanism for local or private packages.
See [local-packages.md](reports/local-packages.md) for a detailed survey of all tools and approaches.

**Simplest approach** — add the local package's `src/` to the app's `source-directories`:

```json
{ "source-directories": ["src", "../my-local-package/src"] }
```

Caveats: must manually sync transitive dependencies, only works in applications, must clean up before committing.
Git submodules or subtrees can formalize this pattern.

**Active tools:**

- [zokka](https://github.com/Zokka-Dev/zokka-compiler) — conservative compiler fork (beta, bidirectionally compatible with Elm 0.19.1).
  Adds custom package repositories, dependency overrides (`zokka-package-overrides` in `elm.json`),
  and single-package locations. Also merges community bug fixes (TCO, etc.).
  Install: `npx zokka`. Publish to custom repos with `zokka publish <url>`.
- [elm-wrap](https://github.com/dsimunic/elm-wrap) — CLI wrapper (pre-1.0, macOS ARM64 / Linux).
  Intercepts the compiler's network requests via a proxy trick, no compiler fork needed.
  Local dev via `wrap package install me/pkg --local-dev --from-path ../pkg-src` (symlinks into `ELM_HOME`).
  Also supports GitHub URL installs, offline mode, and package publishing.
- [elm-janitor/apply-patches](https://github.com/elm-janitor/apply-patches) — replaces core packages
  (`elm/core`, `elm/json`, `elm/parser`) in `ELM_HOME` with community-patched versions. v1.0.0.

### Compress with esbuild and brotli

```
"compress": "esbuild static/main.js --minify --allow-overwrite --outfile=static/main.js && brotli -f -Z static/main.js static/elm-cardano.js static/elm-concurrent-task.js static/storage.js static/json-ld-contexts.js static/pkg-uplc-wasm/pkg-web/uplc_wasm_bg.wasm static/css/output.css",
```

### Lamdera

The [Lamdera compiler](https://github.com/lamdera/compiler) is an open-source, backwards-compatible
un-fork of the Elm compiler. It can compile any Elm 0.19 project using the same commands,
while providing additional optimizations and features.

Lamdera is also a [full-stack Elm platform](https://lamdera.com/) where both frontend and backend
are written in Elm, with messages passed between them without glue code.
Lamdera is a real time-saver if your project fits the constraints it imposes.

### Code generation with elm-codegen

[elm-codegen](https://github.com/mdgriffith/elm-codegen) generates Elm source files programmatically.
You build an AST with a composable Elm API (`Elm.Expression`, `Elm.Declaration`, `Elm.File`)
and get properly formatted code with auto-inferred type signatures and imports.

Key commands: `elm-codegen init` scaffolds a `codegen/` directory with `Generate.elm`,
`elm-codegen run` executes it (supports `--output`, `--watch`, `--flags`),
and `elm-codegen install <package>` generates typed helper bindings under `codegen/Gen/`
so your generator can reference any package's API (e.g. `Gen.Html.div`).

Helper modules provide several variants: direct bindings, `call_` (accepts `Elm.Expression` args),
`make_` (custom type constructors), `values_`, and `annotation_`.
Entry points: `Generate.run` (no input), `Generate.fromJson` (JSON flags), `fromText`, `fromDirectory`.

### OpenAPI generators with elm-open-api-cli

[elm-open-api-cli](https://github.com/wolfadex/elm-open-api-cli) generates an Elm SDK
from an OpenAPI spec. Install with `npm install -D elm-open-api`, then run:

```bash
npx elm-open-api ./path/to/oas.json --module-name="MyApi" --output-dir="src"
```

Generates four modules: `Api` (HTTP request functions), `Json` (encoders/decoders),
`Types` (type definitions — enums become custom types), and `OpenApi/Common` (shared utilities).
Supports `elm/http`, Lamdera's `Effect.Http`, and `elm-pages` `BackendTask.Http`.

Uses elm-codegen internally. Swagger 2.0 specs are auto-converted to OpenAPI 3.x (via `--auto-convert-swagger`).
The `--overrides` flag lets you patch malformed specs, and `--generateTodos` emits `Debug.todo`
stubs for unsupported endpoints instead of failing.

Gotcha: multi-file specs with `$ref` to separate files are not yet supported — the spec must be a single file.

## Packages

### Virtual DOM kernel patching with elm-safe-virtual-dom

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

### Extra Core Functions with core-extra

[elmcraft/core-extra](https://github.com/elmcraft/core-extra) extends Elm's standard library
with community-contributed utility functions. It consolidates several previously separate packages
(elm-community extras, cmd-extra, tuple-extra, set-extra, elm-ordering) into a single dependency.

Modules: `Array.Extra`, `Basics.Extra`, `Char.Extra`, `Cmd.Extra`, `Dict.Extra`, `Float.Extra`,
`List.Extra`, `Maybe.Extra`, `Order.Extra`, `Result.Extra`, `Set.Extra`, `String.Extra`,
`Tuple.Extra`, `Triple.Extra`.

### UI with elm-ui

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

### Task Ports with elm-concurrent-task

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

### IndexedDB with elm-indexeddb

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

### Progressive Web Apps with elm-pwa

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

### Navigation and URL handling with ports and elm-app-url

Use `Browser.element` with two ports instead of `Browser.application`:
`navigationOut` (Elm -> JS) sends tagged JSON to request navigation actions,
and `onNavigation` (JS -> Elm) echoes back `{href, state}` after navigation occurs.
JS handles `history.pushState` / `replaceState` and `popstate` events.

Three navigation patterns:

1. **`pushUrl`** — Standard SPA page navigation. JS calls `pushState`, then notifies Elm of the new URL. Back button works via `popstate`.
2. **`pushState` with state object** — Multi-step flows (e.g. wizard) where the URL stays the same but a state object (e.g. `{wizardStep: 2}`) tracks progress. Back button restores previous state atomically with the URL, avoiding flicker.
3. **`replaceUrl`** — Cosmetic URL updates (e.g. `/about#3`) without creating a history entry and without notifying Elm. The model remains the source of truth.

The [elm-app-url package](https://github.com/lydell/elm-app-url) is used to parse URLs and extract query parameters.

See [examples/navigation](examples/navigation/) for a working demo.

### WebSockets with elm-websocket-manager

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

### Languages i18n with travelm-agency

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

### Big Integers with elm-integer

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

### Markdown Parsing with elm-markdown

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

### Remote Data state with remotedata

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

### Dicts of custom keys with any-dict

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

### Cardano Interop with elm-cardano

https://github.com/elm-cardano/elm-cardano
