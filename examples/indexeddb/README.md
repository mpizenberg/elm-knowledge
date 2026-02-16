# IndexedDB with elm-indexeddb

This example demonstrates [elm-indexeddb](../../elm-indexeddb/) for persistent browser storage in Elm. It implements a todo list that exercises every function in the elm-indexeddb API.

## How it works

`elm-indexeddb` wraps the browser's IndexedDB API as composable `ConcurrentTask` operations. It uses phantom types to enforce correct key handling at compile time.

The app defines three stores (one of each type) and a schema:

```elm
todosStore : IndexedDb.Store IndexedDb.InlineKey          -- key from value's "id" field
todosStore = IndexedDb.defineStore "todos" |> IndexedDb.withKeyPath "id"

settingsStore : IndexedDb.Store IndexedDb.ExplicitKey     -- key provided on each write
settingsStore = IndexedDb.defineStore "settings"

logStore : IndexedDb.Store IndexedDb.GeneratedKey         -- key auto-generated
logStore = IndexedDb.defineStore "log" |> IndexedDb.withAutoIncrement

appSchema = IndexedDb.schema "todoapp" 1
    |> IndexedDb.withStore todosStore
    |> IndexedDb.withStore settingsStore
    |> IndexedDb.withStore logStore
```

## API coverage

Every elm-indexeddb function is used in this example:

| Function | Where used |
|----------|-----------|
| `schema`, `withStore` | `appSchema` — builds the schema with all 3 stores |
| `defineStore` | All 3 store definitions |
| `withKeyPath` | `todosStore` (InlineKey) |
| `withAutoIncrement` | `logStore` (GeneratedKey) |
| `open` | `loadApp` — opens database, applies schema |
| `deleteDatabase` | "Reset database" button — deletes and re-opens |
| `get` | `loadData` — reads theme setting (`Maybe String`) |
| `getAll` | `loadData` — loads all todos |
| `getAllKeys` | `loadData` — fetches todo primary keys for display |
| `count` | `loadData` — counts log entries |
| `add` | `addTodoTask` — insert-only (fails if id exists) |
| `put` | `toggleTodoTask` — upserts toggled todo |
| `addAt` | `initDefaults` — seeds default theme (ignores AlreadyExists) |
| `putAt` | `toggleThemeTask` — saves theme to settings store |
| `insert` | `addTodoTask` — logs action with auto-generated key |
| `delete` | `deleteTodoTask` — removes a single todo |
| `clear` | "Clear todos" button — empties the todos store |
| `putMany` | "Add sample data" — batch-inserts sample todos |
| `putManyAt` | "Add sample data" — batch-inserts sample settings |
| `insertMany` | "Add sample data" — batch-inserts sample log entries |
| `deleteMany` | "Delete completed" button — removes all done todos |

The `keyToString` helper also pattern-matches all four `Key` constructors (`StringKey`, `IntKey`, `FloatKey`, `CompoundKey`).

## Key patterns

- **Phantom types**: `Store InlineKey` means the key comes from the value's `keyPath`. The compiler prevents calling `putAt` (which requires `Store ExplicitKey`) on this store.
- **`addAt` with error recovery**: `initDefaults` uses `addAt` to seed a default theme, then `onError` to silently ignore `AlreadyExists` on subsequent loads.
- **Parallel loading**: `loadData` uses `ConcurrentTask.map4` to run `getAll`, `get`, `count`, and `getAllKeys` concurrently.
- **Parallel writes**: `addTodoTask` uses `ConcurrentTask.map2` to insert the todo and log entry concurrently.
- **Batch + reload**: "Add sample data" uses `ConcurrentTask.batch` for parallel batch writes, then `andThenDo` to reload data.
- **Reset cycle**: "Reset database" calls `deleteDatabase`, then re-runs the full `loadApp` flow (`open` → `addAt` defaults → `loadData`).

## Running the example

```sh
npm install
elm make src/Main.elm --output=static/elm.js
npx esbuild src/index.js --bundle --outfile=static/main.js
cd static
python3 -m http.server 8000
```

Open `http://localhost:8000` in your browser. Add some todos, reload the page — they persist. Toggle the theme — it persists too.

## Project structure

```
indexeddb/
  elm.json          -- Elm deps + source-directories includes ../../elm-indexeddb/elm/src
  package.json      -- JS dependency (@andrewmacmurray/elm-concurrent-task)
  src/
    Main.elm        -- Elm app: todo list exercising every elm-indexeddb function
    index.js        -- JS runner: registers elm-indexeddb tasks, wires up ports
  static/
    index.html      -- HTML shell (loads elm.js + main.js)
    elm.js          -- compiled Elm output (generated)
    main.js         -- bundled JS output (generated)
```
