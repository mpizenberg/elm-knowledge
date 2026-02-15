module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput)
import Markdown.Block as Block
import Markdown.Html
import Markdown.Parser
import Markdown.Renderer exposing (Renderer)



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view
        }



-- MODEL


type alias Model =
    { input : String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { input = sampleMarkdown }
    , Cmd.none
    )


sampleMarkdown : String
sampleMarkdown =
    """# Elm Markdown Demo

This is a **live preview** of the `dillonkearns/elm-markdown` package.

## Features

- Custom heading IDs for *anchor links*
- A `<callout>` custom HTML tag
- Standard markdown: **bold**, *italic*, `code`

### Code Example

```elm
view : Model -> Html Msg
view model =
    div [] [ text "Hello!" ]
```

Here is a [link to Elm](https://elm-lang.org).

<callout type="info">
This is an **info** callout rendered from a custom HTML tag.
</callout>

<callout type="warning">
Be careful with this! The `defaultHtmlRenderer` rejects all HTML by default.
</callout>

## Ordered List

1. Parse markdown into blocks
2. Render blocks with a custom renderer
3. Display the result
"""



-- UPDATE


type Msg
    = UpdateInput String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateInput newInput ->
            ( { model | input = newInput }
            , Cmd.none
            )



-- RENDERER


customRenderer : Renderer (Html Msg)
customRenderer =
    let
        default =
            Markdown.Renderer.defaultHtmlRenderer
    in
    { default
        | heading = viewHeading
        , html = customHtmlRenderer
    }


viewHeading : { level : Block.HeadingLevel, rawText : String, children : List (Html Msg) } -> Html Msg
viewHeading { level, rawText, children } =
    let
        idAttr =
            rawText
                |> String.toLower
                |> String.replace " " "-"

        tag =
            case level of
                Block.H1 ->
                    h1

                Block.H2 ->
                    h2

                Block.H3 ->
                    h3

                Block.H4 ->
                    h4

                Block.H5 ->
                    h5

                Block.H6 ->
                    h6
    in
    tag [ id idAttr ] children


customHtmlRenderer : Markdown.Html.Renderer (List (Html Msg) -> Html Msg)
customHtmlRenderer =
    Markdown.Html.oneOf
        [ Markdown.Html.tag "callout"
            (\maybeType children ->
                let
                    ( borderColor, bgColor, label ) =
                        case maybeType of
                            Just "warning" ->
                                ( "#e67e22", "#fef9e7", "Warning" )

                            _ ->
                                ( "#3498db", "#ebf5fb", "Info" )
                in
                div
                    [ style "border-left" ("4px solid " ++ borderColor)
                    , style "background-color" bgColor
                    , style "padding" "12px 16px"
                    , style "margin" "16px 0"
                    , style "border-radius" "0 4px 4px 0"
                    ]
                    (strong [] [ text (label ++ ": ") ] :: children)
            )
            |> Markdown.Html.withOptionalAttribute "type"
        ]



-- VIEW


view : Model -> Html Msg
view model =
    div [ style "display" "flex", style "gap" "24px", style "padding" "20px", style "font-family" "sans-serif" ]
        [ div [ style "flex" "1" ]
            [ h2 [] [ text "Markdown Input" ]
            , textarea
                [ value model.input
                , onInput UpdateInput
                , style "width" "100%"
                , style "height" "500px"
                , style "font-family" "monospace"
                , style "font-size" "14px"
                , style "padding" "12px"
                , style "box-sizing" "border-box"
                ]
                []
            ]
        , div [ style "flex" "1" ]
            [ h2 [] [ text "Preview" ]
            , viewPreview model.input
            ]
        ]


viewPreview : String -> Html Msg
viewPreview input =
    case
        input
            |> Markdown.Parser.parse
            |> Result.mapError (List.map Markdown.Parser.deadEndToString >> String.join "\n")
            |> Result.andThen (Markdown.Renderer.render customRenderer)
    of
        Ok rendered ->
            div [ style "border" "1px solid #ddd", style "padding" "16px", style "border-radius" "4px" ]
                rendered

        Err errorMessage ->
            pre [ style "color" "red", style "white-space" "pre-wrap" ]
                [ text ("Error:\n" ++ errorMessage) ]
