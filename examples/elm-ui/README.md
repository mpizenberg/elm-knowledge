# elm-ui v2 Example

This example demonstrates [elm-ui v2](https://github.com/mdgriffith/elm-ui/tree/2.0) — a profile card page showcasing core layout, styling, and interaction patterns.

## What it demonstrates

- **Layout**: `el`, `row`, `column` with `padding` + `spacing` (no margins)
- **Sizing**: `fill`, `px`, `portion`, `widthMax`
- **Styling**: `background`, `border`, `borderColor`, `rounded` — all in the `Ui` module (v2 merged `Background`/`Border`)
- **Colors**: `rgb` with 0–255 integers (not 0.0–1.0 floats)
- **Typography**: `Font.size`, `Font.bold`, `Font.color`, `Font.family`
- **Attribute composition**: `attrIf` for conditional styling (active tab highlighting)
- **Button as attribute**: `Input.button msg` on an `el` (not a separate element)
- **Link as attribute**: `Ui.link url` on an `el`
- **Alignment**: `centerX`, `alignRight`, `contentCenterX`/`contentCenterY` (new in v2)
- **Responsive design**: `Responsive.rowWhen` for pure CSS breakpoints (feature cards stack on mobile)
- **Design module**: centralized color palette, typography, and component styles via `Attribute msg` values and `attrs` batching

## Setup

elm-ui v2 and its animation library are not published as packages yet. Their sources are included as git submodules. Initialize them with:

```sh
git submodule update --init
```

This pulls the sources into `elm-ui/` and `elm-animator/`, both referenced in `elm.json`'s `source-directories`.

## Running the example

```sh
elm make src/Main.elm --output=static/elm.js
cd static
python3 -m http.server 8000
```

Open `http://localhost:8000` in your browser.

## Reference

See [elm-ui-v2.md](elm-ui-v2.md) for a detailed v2 API reference covering module structure, layout, styling, responsive design, animation, typography, and migration gotchas from v1.

## Project structure

```
elm-ui/
  elm.json          -- Elm config (source-directories includes elm-ui/src)
  src/Main.elm      -- Profile card demo using elm-ui v2
  src/Design.elm    -- Centralized design tokens (colors, typography, components)
  static/
    index.html      -- HTML shell
    elm.js          -- compiled Elm output (generated)
  elm-ui/           -- elm-ui v2 source (git submodule)
  elm-animator/     -- elm-animator v2 source (git submodule)
  elm-ui-v2.md      -- detailed v2 API reference
```
