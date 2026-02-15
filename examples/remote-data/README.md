# Remote Data with remotedata

This example demonstrates the [RemoteData](https://github.com/krisajenkins/remotedata) pattern for handling HTTP request state in Elm. It fetches posts from JSONPlaceholder, showing all 4 states of `RemoteData`.

## How it works

Instead of modeling HTTP state with `{ data : Maybe a, loading : Bool, error : Maybe String }` (which allows invalid combinations like `loading = True` AND `error = Just "..."`), `RemoteData` uses a single union type:

```elm
type RemoteData e a
    = NotAsked    -- no request made yet
    | Loading     -- request in progress
    | Failure e   -- request failed
    | Success a   -- request succeeded
```

The `WebData a` alias is `RemoteData Http.Error a`, which is the common case for HTTP fetches.

The app starts in `NotAsked` state with a "Load Posts" button. Clicking it transitions to `Loading`, then to `Success` or `Failure` depending on the HTTP response. Each state is rendered differently in the view via exhaustive pattern matching.

## Key patterns

- **HTTP integration**: `Http.expectJson (RemoteData.fromResult >> GotPosts) decoder` converts the `Result` from `Http.expectJson` into a `RemoteData` value in one line
- **Set Loading before request**: In `update`, set `model.posts = Loading` before firing the HTTP command
- **Exhaustive case match in view**: Pattern match on all 4 variants to ensure every state is handled

## Running the example

```sh
elm make src/Main.elm --output=static/elm.js
cd static
python3 -m http.server 8000
```

Open `http://localhost:8000` in your browser. The HTTP fetch goes to `https://jsonplaceholder.typicode.com/posts`.

## Project structure

```
remote-data/
  elm.json          -- Elm dependencies (elm/http, krisajenkins/remotedata)
  src/Main.elm      -- Elm app: fetch posts, display all 4 RemoteData states
  static/
    index.html      -- HTML shell (no ports needed)
    elm.js          -- compiled Elm output (generated)
```
