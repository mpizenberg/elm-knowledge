# Markdown Parsing with elm-markdown

This example demonstrates the [dillonkearns/elm-markdown](https://github.com/dillonkearns/elm-markdown) package for parsing and rendering markdown in Elm. It implements a live editor/previewer with custom rendering.

## How it works

`elm-markdown` uses a two-step pipeline: **parse** the markdown string into `Block` values, then **render** those blocks into any output type using a `Renderer`.

```elm
input
    |> Markdown.Parser.parse
    |> Result.andThen (Markdown.Renderer.render customRenderer)
```

The `Renderer` type is a record with one field per markdown element (heading, paragraph, link, codeBlock, etc.). You start from `defaultHtmlRenderer` and override the fields you need.

## Key patterns

- **Custom heading renderer**: Override the `heading` field to add `id` attributes derived from the heading text, enabling anchor links
- **Custom HTML tags**: Use `Markdown.Html.oneOf` with `Markdown.Html.tag` to support custom tags like `<callout type="info">`. Each tag handler chains `withAttribute` / `withOptionalAttribute` to extract attributes
- **Error display**: Both `parse` and `render` return `Result`, so errors (invalid markdown or unhandled HTML tags) can be shown inline

## Gotcha

`defaultHtmlRenderer` rejects all HTML tags by default. If your markdown contains any HTML (even `<div>`), rendering will fail unless you provide a custom `html` handler via `Markdown.Html.oneOf` listing every tag you want to support.

## Running the example

```sh
elm make src/Main.elm --output=static/elm.js
cd static
python3 -m http.server 8000
```

Open `http://localhost:8000` in your browser.

## Project structure

```
markdown/
  elm.json          -- Elm dependencies (dillonkearns/elm-markdown)
  src/Main.elm      -- Elm app: live markdown editor with custom renderer
  static/
    index.html      -- HTML shell
    elm.js          -- compiled Elm output (generated)
```
