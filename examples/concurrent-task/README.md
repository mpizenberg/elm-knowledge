# Task Ports with elm-concurrent-task

This example demonstrates [elm-concurrent-task](https://github.com/andrewMacmurray/elm-concurrent-task) for composable port-based tasks in Elm. It implements a profile editor that reads and writes to localStorage.

## How it works

`elm-concurrent-task` replaces the usual one-command-per-message port pattern with composable tasks that can run concurrently or sequentially. Tasks communicate with JS through two ports (`send` and `receive`) and a task pool.

The app defines two custom JS tasks (`localstorage:getItem` and `localstorage:setItem`) and composes them:

- **On init**: reads name and color concurrently with `ConcurrentTask.map2`
- **On save**: writes both values concurrently with `ConcurrentTask.batch`

## Key patterns

- **Define a task**: `ConcurrentTask.define { function, expect, errors, args }` — the `function` string maps to a JS function registered with `ConcurrentTask.register`
- **Concurrent**: `map2`, `map3`, `batch` run tasks in parallel and collect results
- **Sequential**: `andThen` chains tasks where the second depends on the first
- **Error protocol**: JS returns `{ error: "CODE" }` for expected errors, which Elm decodes via `expectErrors`. Plain return values are successes.
- **Pool wiring**: Store `ConcurrentTask.Pool` in the model, use `attempt` to start tasks, `onProgress` as a subscription, and handle `OnProgress (pool, cmd)` in update

## Built-in modules

The package ships with drop-in replacements for common `elm/core` and `elm/browser` tasks, so they can be composed with custom tasks in a single pipeline:

- `ConcurrentTask.Http` — `get`, `post`, `request` (like `elm/http` but composable with other tasks)
- `ConcurrentTask.Browser.Dom` — `focus`, `blur`, `getElement`, `getViewport`, `setViewport`
- `ConcurrentTask.Time` — `now`, `here`, `getZoneName`, plus `withDuration` to time any task
- `ConcurrentTask.Process` — `sleep`, `withTimeout` (cancel a task after N ms with a fallback value)
- `ConcurrentTask.Random` — `generate` from any `Random.Generator`

## Good use cases

- **App initialization**: load multiple resources concurrently on startup (localStorage, HTTP, DOM measurements) instead of bouncing through `update` for each one
- **Multi-step workflows**: read config → fetch API → write result, expressed as a single `andThen` chain instead of separate Msg/Cmd round-trips
- **Parallel HTTP**: fetch multiple endpoints with `batch` and collect all results at once
- **Timed operations**: wrap any task with `ConcurrentTask.Time.withDuration` to measure how long it took

## JS runner setup

The JS side registers task functions with `ConcurrentTask.register`:

```js
import * as ConcurrentTask from "@andrewmacmurray/elm-concurrent-task";

ConcurrentTask.register({
  tasks: { "localstorage:getItem": getItem, "localstorage:setItem": setItem },
  ports: { send: app.ports.send, receive: app.ports.receive },
});
```

Task functions receive the `args` JSON as their argument and return a value (sync or Promise), or `{ error: ... }` for expected errors.

## Running the example

```sh
npm install
elm make src/Main.elm --output=static/elm.js
npx esbuild src/index.js --bundle --outfile=static/main.js
cd static
python3 -m http.server 8000
```

Open `http://localhost:8000` in your browser.

## Project structure

```
concurrent-task/
  elm.json          -- Elm dependencies (andrewMacmurray/elm-concurrent-task)
  package.json      -- JS dependency (@andrewmacmurray/elm-concurrent-task)
  src/
    Main.elm        -- Elm app: profile editor with concurrent localStorage tasks
    index.js        -- JS runner: registers task functions, wires up ports
  static/
    index.html      -- HTML shell (loads elm.js + main.js)
    elm.js          -- compiled Elm output (generated)
    main.js         -- bundled JS output (generated)
```
