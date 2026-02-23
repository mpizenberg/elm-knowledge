# Tooling

In this document, we gather some of the most useful tools to enhance your Elm applications.

## Tooling Installation with elm-tooling-cli

[elm-tooling-cli](https://github.com/elm-tooling/elm-tooling-cli) manages Elm tool versions
(elm, elm-format, elm-json, elm-test-rs) via an `elm-tooling.json` file,
as a faster and more secure drop-in replacement for installing them through npm.

Setup: `npx elm-tooling init` generates the config, `npx elm-tooling install` fetches the tools.
Add `"postinstall": "elm-tooling install"` to `package.json` scripts so tools are installed
automatically on `npm install`.

## CI with elm-tooling-action

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

## Update dependencies with elm-json

[elm-json](https://github.com/zwilias/elm-json) is a CLI tool for managing Elm dependencies.
Key commands: `elm-json install elm/http` (or `elm/http@2` for a major version),
`elm-json uninstall elm/html`, `elm-json upgrade` (patch/minor only; `--unsafe` allows major bumps),
and `elm-json tree` to visualize the dependency graph.

For applications it pins exact versions and resolves indirect deps;
for packages it sets version ranges. Note: `upgrade` only works for applications, not packages.

## Publish elm packages with elm-publish-action

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

## Code Formatting with elm-format

[elm-format](https://github.com/avh4/elm-format) formats Elm source code according to a standard
set of rules based on the official Elm Style Guide. Run `elm-format .` (or `elm-format Main.elm --yes`)
to format files. Most editors support format-on-save integration.

## Linting with elm-review

[elm-review](https://github.com/jfmengels/node-elm-review) is a static analysis tool for Elm.
It ships with no built-in rules — you configure them in a `review/` directory
(`ReviewConfig.elm` + `elm.json`) by installing rule packages (e.g. `jfmengels/elm-review-unused`).

Key commands: `elm-review init` scaffolds the config, `elm-review` analyzes the project,
`elm-review --fix` offers automatic fixes.
Quick test without setup: `npx elm-review --template jfmengels/elm-review-unused/example`.

## Hot Reload with elm-watch

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

## Local Docs with elm-doc-preview

[elm-doc-preview](https://github.com/dmy/elm-doc-preview) is an offline documentation previewer
for Elm packages and applications, with hot reloading. Run `elm-doc-preview` (or `edp`) from
your project directory. For applications, create an `elm-application.json` specifying
`exposed-modules`, `name`, `summary`, and `version`.

## Local packages development

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

## Compress with esbuild and brotli

```
"compress": "esbuild static/main.js --minify --allow-overwrite --outfile=static/main.js && brotli -f -Z static/main.js static/elm-cardano.js static/elm-concurrent-task.js static/storage.js static/json-ld-contexts.js static/pkg-uplc-wasm/pkg-web/uplc_wasm_bg.wasm static/css/output.css",
```

## Lamdera

The [Lamdera compiler](https://github.com/lamdera/compiler) is an open-source, backwards-compatible
un-fork of the Elm compiler. It can compile any Elm 0.19 project using the same commands,
while providing additional optimizations and features.

Lamdera is also a [full-stack Elm platform](https://lamdera.com/) where both frontend and backend
are written in Elm, with messages passed between them without glue code.
Lamdera is a real time-saver if your project fits the constraints it imposes.

## Code generation with elm-codegen

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

## OpenAPI generators with elm-open-api-cli

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
