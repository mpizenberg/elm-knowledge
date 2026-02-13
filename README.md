# Elm Knowledge

This repository aims to provide a knowledge base to develop Elm applications.
It contains both generic information, and some of my preferences.

## Architecture

- Modules focused on a data structure
- Always expose the minimum required api from modules
- Avoid `Browser.Application` as a main, and prefer `Browser.Element` with routing handled via ports

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

### URL handling with elm-app-url

https://github.com/lydell/elm-app-url

### Languages i18n with travelm-agency

https://github.com/anmolitor/travelm-agency

### Big Integers with elm-integer

https://github.com/dwayne/elm-integer
https://github.com/dwayne/elm-natural

### Markdown Parsing with elm-markdown

https://github.com/dillonkearns/elm-markdown

### Remote Data state with remotedata

https://github.com/krisajenkins/remotedata

### Dicts of custom keys with any-dict

https://github.com/turboMaCk/any-dict

### Cardano Interop with elm-cardano

https://github.com/elm-cardano/elm-cardano
