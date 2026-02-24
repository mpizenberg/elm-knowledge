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

See [KNOWLEDGE_TOOLING.md](KNOWLEDGE_TOOLING.md) for details.

- elm-tooling-cli — manages Elm tool versions via `elm-tooling.json`, replacing npm installs
- elm-tooling-action — GitHub Action that installs Elm tools from `elm-tooling.json` with caching
- elm-json — CLI for installing, uninstalling, and upgrading Elm dependencies
- elm-publish-action — GitHub Action that auto-publishes Elm packages when the version is bumped
- elm-format — formats Elm source code according to the official style guide
- elm-review — configurable static analysis and linting for Elm projects
- elm-watch — file watcher with hot reloading that preserves application state
- elm-doc-preview — offline documentation previewer with hot reloading
- Local packages — approaches for using local/private Elm packages (source-directories, zokka, elm-wrap)
- Lamdera — open-source backwards-compatible un-fork of the Elm compiler with extra optimizations
- elm-codegen — generates Elm source files programmatically from a composable AST API
- elm-open-api-cli — generates an Elm SDK from an OpenAPI spec

## Packages

See [KNOWLEDGE_PACKAGES.md](KNOWLEDGE_PACKAGES.md) for details.

- elm-safe-virtual-dom — patched virtual DOM that fixes crashes from browser extensions and Google Translate
- core-extra — community-contributed utility functions extending Elm's standard library
- elm-ui — UI layout library with the philosophy "if it compiles, layout is correct"
- elm-concurrent-task — composable, concurrent tasks that can call JS, replacing port boilerplate
- elm-indexeddb — IndexedDB support via elm-concurrent-task with phantom-typed key discipline
- elm-pwa — port-based bridge for PWA APIs (service workers, install prompts, push notifications)
- elm-url-navigation-port — port-based SPA navigation for `Browser.element`
- elm-websocket-manager — type-safe WebSocket management with auto-reconnection and binary support
- travelm-agency — compile-time i18n with strongly-typed translation functions
- elm-natural / elm-integer — arbitrary-precision natural and signed integers
- elm-markdown — customizable markdown parser with a two-step parse-then-render pipeline
- remotedata — replaces `Maybe`/`Bool`/`error` combos with a single `NotAsked | Loading | Failure | Success` type
- any-dict — dictionaries keyed by any type via a `toComparable` function
- elm-form — UI-agnostic form library decoupling state, validation, and rendering
- elm-cardano — Cardano blockchain interop for Elm
