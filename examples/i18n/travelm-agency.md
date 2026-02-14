# travelm-agency -- Elm i18n Code Generation

Repository: https://github.com/anmolitor/travelm-agency
Author: Andreas Molitor (anmolitor)
Version at time of writing: 3.8.0
Interactive tutorial: https://anmolitor.github.io/travelm-agency

## Overview

travelm-agency is a compile-time i18n solution for Elm.
You write translation files in JSON, Properties, or Fluent (.ftl) format,
and the tool generates a strongly-typed Elm module with one function per translation key.
Placeholder requirements are enforced at compile time.

There are two deployment modes:

- **Inline**: All translations are embedded in the generated Elm code.
  Smaller bundle (no elm/http or elm/parser needed), but requires recompilation to change translations.
- **Dynamic**: Translations are loaded at runtime from optimized JSON files via HTTP.
  Enables hot language switching without recompilation, but slightly larger bundle.

## Translation File Formats

Files must follow the naming convention: `[identifier].[language].[extension]`

Examples:
```
translations/
  messages.en.json
  messages.de.json
```
or
```
translations/
  messages.en.properties
  messages.de.properties
```
or
```
translations/
  messages.en.ftl
  messages.de.ftl
```

### JSON Format

Top-level object with string values. Nested objects are allowed (keys get camelCased).
No arrays, numbers, or comments.

```json
{
  "greeting": "Hello, {name}!",
  "plan": "On {day}, I want to {todo}.",
  "simpleText": "Just a static string"
}
```

- Placeholders: `{name}`
- Escape literal brace: `\{`
- HTML: `<b>bold text</b>` (triggers `List (Html msg)` return type)
- Escape literal `<`: `\<`
- Fallback language: `{ "--fallback-language": "en" }`

### Properties Format

Key=value pairs, one per line. Multiline values end non-final lines with `\`.
Comments start with `#`.

```properties
greeting = Hello, {name}!
plan = On {day}, I want to {todo}.
longText = This is a long text \
    that spans multiple lines.
```

- Placeholders: `{name}`
- Escape literal brace: `'{' `
- HTML: `<b>bold text</b>`
- Escape literal `<`: `'<'`
- Fallback language: `# fallback-language: en`

### Fluent (.ftl) Format

Full Project Fluent syntax. This is the most powerful format.

```ftl
greeting = Hello, { $name }!
plan = On { $day }, I want to { $todo }.

# Terms are reusable and inlined at compile time
-app-name = MyApp
welcome = Welcome to { -app-name }

# Case interpolation (selectors)
fruit-description = { $fruit ->
    [apple] A red fruit.
    [banana] A yellow fruit.
   *[other] Some fruit.
}

# Plural rules (requires intl-proxy)
page-count = { NUMBER($count) ->
    [one] one page
   *[other] { $count } pages
}

# Number formatting (requires intl-proxy)
price = The price is { NUMBER($amount, style: "currency", currency: "EUR") }.

# Date formatting (requires intl-proxy)
today = Today is { DATETIME($date, dateStyle: "full") }.
```

- Placeholders: `{ $variable }`
- Terms: `-term-name = value`, referenced as `{ -term-name }`
- Selectors/case interpolation: match on string values
- Plural rules: wrap variable in `NUMBER()` and match on categories (zero, one, two, few, many, other)
- Number formatting: `NUMBER($var, option: "value")`
- Date formatting: `DATETIME($var, option: "value")`
- HTML escaping: use string literals `{ "<" }` to produce a literal `<`
- Fallback language: `# fallback-language: en`

## Installation and Setup

### npm dependency

```bash
npm install --save-dev travelm-agency
```

### Elm dependencies

For **inline** mode, no extra Elm dependencies are needed beyond elm/core and elm/html.

For **dynamic** mode, you need:
- `elm/http` (to fetch translation JSON files)
- `elm/parser` (used internally by the generated decoder)

If you use Fluent NUMBER/DATETIME/plural features:
- `npm install intl-proxy` (the npm package)
- `elm install anmolitor/intl-proxy` (the Elm package)

### CLI Usage

```bash
npx travelm-agency [translation-folder] --elm_path=src/Translations.elm --json_path=dist/i18n
```

All CLI options:

| Flag | Default | Description |
|------|---------|-------------|
| `--elm_path` | `src/Translations.elm` | Output path for the generated Elm module |
| `--json_path` | `dist/i18n` | Output directory for optimized translation JSON files |
| `--inline` | `false` | Embed all translations in Elm code (no JSON output) |
| `--hash` | `false` | Add content hash to JSON filenames for cache busting |
| `--i18n_arg_first` | `false` | Put the `I18n` argument first instead of last |
| `--prefix_file_identifier` | `false` | Prefix function names with the file identifier (useful with multiple translation files/bundles) |
| `--devMode` | `false` | Disable completeness validation of keys across languages |
| `--custom_html_module` | `Html` | Use a different Html module (e.g. for elm-css) |
| `--custom_html_attributes_module` | `Html.Attributes` | Use a different attributes module |

Example in package.json scripts:

```json
{
  "scripts": {
    "i18n": "travelm-agency translations --elm_path=src/I18n.elm --json_path=public/i18n",
    "i18n:inline": "travelm-agency translations --elm_path=src/I18n.elm --inline",
    "prebuild": "npm run i18n"
  }
}
```

## Generated Elm Module Shape

The generated module name is derived from the `--elm_path` argument
(e.g. `src/Translations.elm` produces `module Translations`).

### Language Type

```elm
type Language
    = En
    | De

languageFromString : String -> Maybe Language
languageToString : Language -> String
languages : List Language
```

`languageFromString` uses prefix matching, so `"en-US"` resolves to `Just En`.

### I18n Type

```elm
-- Opaque type
type I18n = ...
```

### init

The signature depends on features used in your translation files:

```elm
-- Basic (inline mode, no Intl features)
init : Language -> I18n

-- With Intl API access (NUMBER/DATETIME/plurals in Fluent)
init : Intl -> Language -> I18n

-- Dynamic mode basic
init : { path : String } -> Language -> I18n

-- Dynamic mode with Intl
init : { path : String, intl : Intl } -> Language -> I18n
```

### Language Accessors

```elm
-- The language the user wants (may differ from what's displayed while loading)
currentLanguage : I18n -> Language

-- The language actually displayed (dynamic mode: reflects what has been loaded)
arrivedLanguage : I18n -> Language
```

### Loading (Dynamic Mode Only)

```elm
-- Load translations for a language. Returns a Cmd and the result is an (I18n -> I18n) update function.
loadMessages :
    { language : Language
    , path : String
    , onLoad : Result Http.Error (I18n -> I18n) -> msg
    }
    -> Cmd msg

-- Switch language and reload all previously-loaded bundles
switchLanguage : Language -> I18n -> ( I18n, Cmd msg )

-- Apply loaded translations
load : (I18n -> I18n) -> I18n -> I18n
```

### Translation Accessors

One function per translation key. The signature depends on what the translation contains:

```elm
-- Simple text (no placeholders)
simpleText : I18n -> String

-- One placeholder
greeting : String -> I18n -> String

-- Multiple placeholders (uses a record)
plan : { day : String, todo : String } -> I18n -> String

-- HTML content (returns Html instead of String)
htmlContent : List (Html.Attribute msg) -> I18n -> List (Html msg)

-- HTML with identified elements (each _id gets its own attribute list)
richContent :
    { link : List (Html.Attribute msg)
    , bold : List (Html.Attribute msg)
    }
    -> I18n -> List (Html msg)

-- Number formatting (Fluent only, requires intl-proxy)
formattedPrice : Float -> I18n -> String

-- Plural rules (Fluent only, requires intl-proxy)
pageCount : Float -> I18n -> String
```

Note: by default, `I18n` is the **last** argument. Use `--i18n_arg_first` to make it the first.

## Using It in an Elm Application

### Inline Mode (Minimal Example)

Elm model:

```elm
type alias Model =
    { i18n : I18n
    , language : Language
    }

init : Model
init =
    { i18n = Translations.init En
    , language = En
    }
```

View:

```elm
view : Model -> Html Msg
view model =
    div []
        [ text (Translations.greeting "World" model.i18n)
        , text (Translations.simpleText model.i18n)
        ]
```

Language switching (inline mode -- just reinitialize):

```elm
type Msg
    = SwitchLanguage Language

update : Msg -> Model -> Model
update msg model =
    case msg of
        SwitchLanguage lang ->
            { model
                | i18n = Translations.init lang
                , language = lang
            }
```

### Dynamic Mode

JavaScript entry point (passes path and optionally intl-proxy):

```javascript
import intlProxy from "intl-proxy";
import { Elm } from "./Main.elm";

Elm.Main.init({
    flags: {
        language: "en",
        intl: intlProxy,         // only if using NUMBER/DATETIME/plurals
        translationPath: "/i18n"  // path where JSON files are served
    }
});
```

Elm model and init:

```elm
type alias Flags =
    { language : String
    , intl : Intl             -- only if using Intl features
    , translationPath : String
    }

type alias Model =
    { i18n : Translations.I18n
    }

init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        language =
            flags.language
                |> Translations.languageFromString
                |> Maybe.withDefault Translations.En

        i18n =
            Translations.init
                { path = flags.translationPath, intl = flags.intl }
                language
    in
    ( { i18n = i18n }
    , Translations.loadMessages
        { language = language
        , path = flags.translationPath
        , onLoad = GotTranslations
        }
    )
```

Handling the loaded translations:

```elm
type Msg
    = GotTranslations (Result Http.Error (Translations.I18n -> Translations.I18n))
    | SwitchLanguage Translations.Language

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotTranslations (Ok apply) ->
            ( { model | i18n = apply model.i18n }, Cmd.none )

        GotTranslations (Err _) ->
            ( model, Cmd.none )

        SwitchLanguage lang ->
            let
                ( newI18n, cmd ) =
                    Translations.switchLanguage lang model.i18n
            in
            ( { model | i18n = newI18n }, cmd )
```

## Features Summary

| Feature | JSON | Properties | Fluent |
|---------|------|------------|--------|
| Simple text | Yes | Yes | Yes |
| Interpolation (placeholders) | Yes | Yes | Yes |
| HTML generation | Yes | Yes | Yes |
| Nested keys | Yes | Yes (dot notation) | No |
| Fallback language | Yes | Yes | Yes |
| Terms (reusable values) | No | No | Yes |
| Case interpolation (selectors) | No | No | Yes |
| Plural rules | No | No | Yes |
| Number formatting (Intl API) | No | No | Yes |
| Date formatting (Intl API) | No | No | Yes |
| Term arguments | No | No | Yes |
| Attributes | No | No | Yes |
| Inline mode | Yes | Yes | Yes |
| Dynamic mode | Yes | Yes | Yes |

## Key Design Decisions

- **Consistency checking**: By default, the tool errors if translation keys differ across language files for the same identifier. Use `--devMode` to disable during development.
- **Fallback chains**: Any language file can declare a fallback language. Missing keys are pulled from the fallback file. The fallback graph must be acyclic.
- **HTML return types**: If a translation contains HTML tags, the accessor function returns `List (Html msg)` instead of `String`. The `_id` attribute on tags lets you target specific elements with attributes at call sites.
- **Bundle splitting**: With multiple translation file identifiers (e.g. `header.en.json`, `footer.en.json`), each gets its own `load` function. Use `--prefix_file_identifier` to namespace the accessor functions (e.g. `headerTitle`, `footerCopyright`).
- **Optimized JSON**: In dynamic mode, the generated JSON files use numeric indices instead of key names and special encoding prefixes, minimizing bundle size.
- **Content hashing**: The `--hash` flag appends a content hash to JSON filenames for browser cache busting.

## Minimal Project Structure

```
my-app/
  elm.json
  package.json
  src/
    Main.elm
    Translations.elm          # generated -- do not edit
  translations/
    messages.en.json
    messages.de.json
  public/
    i18n/                     # generated JSON (dynamic mode only)
      messages.en.xxxxx.json  # optimized, possibly hashed
      messages.de.xxxxx.json
```

elm.json direct dependencies (dynamic mode with Intl):
```json
{
  "elm/browser": "1.0.2",
  "elm/core": "1.0.5",
  "elm/html": "1.0.0",
  "elm/http": "2.0.0",
  "elm/json": "1.1.3",
  "anmolitor/intl-proxy": "1.0.0"
}
```

package.json:
```json
{
  "devDependencies": {
    "travelm-agency": "^3.8.0"
  },
  "dependencies": {
    "intl-proxy": "^1.0.1"
  },
  "scripts": {
    "i18n": "travelm-agency translations --elm_path=src/Translations.elm --json_path=public/i18n",
    "prebuild": "npm run i18n"
  }
}
```

## Comparison with Alternatives

| Solution | Approach | Limitations vs travelm-agency |
|----------|----------|-------------------------------|
| elm-i18next-gen | Generates code from i18next JSON | Unsafe Dict-based access; multiple modules |
| elm-i18n | Separate JS bundle per language | Difficult runtime language switching |
| i18n-to-elm | Code generation | Inline mode only |
| elm-i18n-module-generator | Code generation with union type | Inline mode only |
| **travelm-agency** | Code generation from JSON/Properties/Fluent | Combines optimized dynamic JSON, Intl API access, and HTML generation |
