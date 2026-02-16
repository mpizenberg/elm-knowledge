# IndexedDB with elm-indexeddb

This example demonstrates [elm-indexeddb](../../elm-indexeddb/) for persistent browser storage in Elm. It implements a todo list that survives page reloads using IndexedDB.

## How it works

`elm-indexeddb` wraps the browser's IndexedDB API as composable `ConcurrentTask` operations. It uses phantom types to enforce correct key handling at compile time.

The app defines one store and a schema:

```elm
todosStore : IndexedDb.Store IndexedDb.InlineKey
todosStore =
    IndexedDb.defineStore "todos"
        |> IndexedDb.withKeyPath "id"

appSchema : IndexedDb.Schema
appSchema =
    IndexedDb.schema "todoapp" 1
        |> IndexedDb.withStore todosStore
```

- **On init**: `open` the database, then `getAll` to load existing todos
- **Add todo**: `put` upserts the todo (key extracted from the `id` field)
- **Toggle todo**: `put` with updated `done` field
- **Delete todo**: `delete` by key
- **Clear all**: `clear` removes all records from the store

## Key patterns

- **Phantom types for stores**: `Store InlineKey` means the key comes from the value's `keyPath`. The compiler prevents calling `putAt` (which requires `Store ExplicitKey`) on this store.
- **Schema-driven migrations**: Adding/removing stores from the schema triggers automatic structural changes on `open`. No manual migration code needed.
- **`open` returns `Db`**: An opaque handle threaded to all operations, proving the database was opened.
- **`get` returns `Maybe`**: Missing keys return `Nothing`, not an error — matching IndexedDB semantics.

## Three store types

```elm
-- InlineKey: key extracted from value at keyPath
defineStore "todos" |> withKeyPath "id"
-- use: put, add, putMany

-- ExplicitKey: key provided separately
defineStore "settings"
-- use: putAt, addAt, putManyAt

-- GeneratedKey: key auto-generated
defineStore "cache" |> withAutoIncrement
-- use: insert, insertMany
```

## Running the example

```sh
npm install
elm make src/Main.elm --output=static/elm.js
npx esbuild src/index.js --bundle --outfile=static/main.js
cd static
python3 -m http.server 8000
```

Open `http://localhost:8000` in your browser. Add some todos, reload the page — they persist.

## Project structure

```
indexeddb/
  elm.json          -- Elm deps + source-directories includes ../../elm-indexeddb/elm/src
  package.json      -- JS dependency (@andrewmacmurray/elm-concurrent-task)
  src/
    Main.elm        -- Elm app: todo list with IndexedDB persistence
    index.js        -- JS runner: registers elm-indexeddb tasks, wires up ports
  static/
    index.html      -- HTML shell (loads elm.js + main.js)
    elm.js          -- compiled Elm output (generated)
    main.js         -- bundled JS output (generated)
```
