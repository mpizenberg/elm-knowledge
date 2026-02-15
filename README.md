# Elm Knowledge

This repository aims to provide a knowledge base to develop Elm applications.
It contains both generic information, and some of my preferences.

## Architecture

- Modules focused on a data structure
- Always expose the minimum required api from modules
- Avoid `Browser.Application` as a main, and prefer `Browser.Element` with routing handled via ports

## Design Patterns

- Extensible record phantom builder pattern (https://www.youtube.com/watch?v=Trp3tmpMb-o)

## Tooling

### Tooling Installation with elm-tooling-cli

https://github.com/elm-tooling/elm-tooling-cli

### Code Formatting with elm-format

https://github.com/avh4/elm-format

### Linting with elm-review

https://github.com/jfmengels/node-elm-review

### Hot Reload with elm-watch

https://github.com/lydell/elm-watch

### Local Docs with elm-doc-preview

https://github.com/dmy/elm-doc-preview

### Local Packages with elm-wrap

https://github.com/dsimunic/elm-wrap

### Compress with esbuild and brotli

```
"compress": "esbuild static/main.js --minify --allow-overwrite --outfile=static/main.js && brotli -f -Z static/main.js static/elm-cardano.js static/elm-concurrent-task.js static/storage.js static/json-ld-contexts.js static/pkg-uplc-wasm/pkg-web/uplc_wasm_bg.wasm static/css/output.css",
```

### CI with elm-tooling-action

https://github.com/mpizenberg/elm-tooling-action

### Lamdera

https://github.com/lamdera/compiler

## Packages

### Virtual Dom kernel patching with elm-safe-virtual-dom

https://github.com/lydell/elm-safe-virtual-dom
https://github.com/cardano-foundation/cardano-governance-voting-tool/tree/production/frontend#virtual-dom-kernel-patching

### Extra Core Functions with core-extra

https://github.com/elmcraft/core-extra

### UI with elm-ui

The best UI and design system for Elm is elm-ui.
Matthew Griffith did a tremendous job at making a UI library with the philosophy "if it compiles, layout is correct".
For humans, I highly recommend watching his talk ["Building a Toolkit for Design"](https://youtu.be/Ie-gqwSHQr0?si=Tz4HFLUNBQuwkFxu).

The v2 of elm-ui has been in the works for a while, and lives in [branch `2.0` of the repository](https://github.com/mdgriffith/elm-ui/tree/2.0).
It isn’t published as a package yet, so to use it, one needs to embed it in their project and adjust all the dependencies and source directories.

### Task Ports with elm-concurrent-task

Ports and commands can be limiting because they don’t have a composition mechanism.
Each command must be dealt with in the `update` function with a dedicated message.
So chaining and composing them is tedious.
The package [elm-concurrent-task](https://github.com/andrewMacmurray/elm-concurrent-task) provides an effective alternative.
It enables running a tree of tasks concurrently, and calling JS as tasks.
Setting it up requires installing both the elm package, and the JS package providing the task-port runtime.

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
