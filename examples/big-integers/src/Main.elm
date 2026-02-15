module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Natural exposing (Natural)



-- MAIN


main : Program () Model Msg
main =
    Browser.sandbox
        { init = init
        , update = update
        , view = view
        }



-- MODEL


type alias Model =
    { input : String
    , result : Maybe Natural
    , baseInput : String
    , targetBase : Int
    }


init : Model
init =
    { input = "20"
    , result = Nothing
    , baseInput = "255"
    , targetBase = 16
    }



-- FACTORIAL


factorial : Natural -> Natural
factorial n =
    factorialHelper Natural.one n


factorialHelper : Natural -> Natural -> Natural
factorialHelper acc n =
    if Natural.isZero n then
        acc

    else
        factorialHelper (Natural.mul acc n) (Natural.sub n Natural.one)



-- BASE CONVERSION


convertBase : Int -> Natural -> String
convertBase base n =
    case base of
        2 ->
            "0b" ++ Natural.toBinaryString n

        8 ->
            "0o" ++ Natural.toOctalString n

        16 ->
            "0x" ++ Natural.toHexString n

        _ ->
            Natural.toString n



-- UPDATE


type Msg
    = SetInput String
    | ComputeFactorial
    | SetBaseInput String
    | SetTargetBase Int


update : Msg -> Model -> Model
update msg model =
    case msg of
        SetInput str ->
            { model | input = str }

        ComputeFactorial ->
            let
                result =
                    model.input
                        |> String.toInt
                        |> Maybe.andThen Natural.fromInt
                        |> Maybe.map factorial
            in
            { model | result = result }

        SetBaseInput str ->
            { model | baseInput = str }

        SetTargetBase base ->
            { model | targetBase = base }



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Big Integer Calculator" ]
        , viewFactorial model
        , hr [] []
        , viewBaseConverter model
        , hr [] []
        , viewSaturatingSub
        ]


viewFactorial : Model -> Html Msg
viewFactorial model =
    div []
        [ h2 [] [ text "Factorial" ]
        , p [] [ text "Elm's Int overflows at 21!. Natural handles arbitrary precision." ]
        , p []
            [ input
                [ type_ "number"
                , value model.input
                , onInput SetInput
                , placeholder "Enter n"
                , Html.Attributes.min "0"
                , style "width" "80px"
                ]
                []
            , text " "
            , button [ onClick ComputeFactorial ] [ text "Compute n!" ]
            ]
        , case model.result of
            Nothing ->
                p [] [ text "Enter a number and click Compute." ]

            Just n ->
                let
                    str =
                        Natural.toString n
                in
                div []
                    [ p [] [ strong [] [ text "Result:" ] ]
                    , p [ style "word-break" "break-all", style "font-family" "monospace" ]
                        [ text str ]
                    , p []
                        [ text (String.fromInt (String.length str) ++ " digits") ]
                    ]
        ]


viewBaseConverter : Model -> Html Msg
viewBaseConverter model =
    let
        parsed =
            Natural.fromString model.baseInput

        converted =
            case parsed of
                Just n ->
                    convertBase model.targetBase n

                Nothing ->
                    "Invalid input"
    in
    div []
        [ h2 [] [ text "Base Converter" ]
        , p []
            [ text "Number: "
            , input
                [ type_ "text"
                , value model.baseInput
                , onInput SetBaseInput
                , placeholder "Enter a decimal number"
                , style "width" "200px"
                ]
                []
            ]
        , p []
            (text "Convert to: "
                :: List.intersperse (text " ")
                    [ radioButton "base" (model.targetBase == 2) (SetTargetBase 2) "Binary"
                    , radioButton "base" (model.targetBase == 8) (SetTargetBase 8) "Octal"
                    , radioButton "base" (model.targetBase == 10) (SetTargetBase 10) "Decimal"
                    , radioButton "base" (model.targetBase == 16) (SetTargetBase 16) "Hex"
                    ]
            )
        , p [ style "word-break" "break-all", style "font-family" "monospace" ]
            [ strong [] [ text "Result: " ]
            , text converted
            ]
        ]


viewSaturatingSub : Html Msg
viewSaturatingSub =
    div []
        [ h2 [] [ text "Saturating Subtraction" ]
        , p [] [ text "Natural.sub uses saturating subtraction: if b > a, then sub a b = 0." ]
        , ul []
            [ li [] [ text ("sub 10 4 = " ++ Natural.toString (Natural.sub Natural.ten (Natural.fromSafeInt 4))) ]
            , li [] [ text ("sub 4 10 = " ++ Natural.toString (Natural.sub (Natural.fromSafeInt 4) Natural.ten)) ]
            , li [] [ text ("sub 0 5 = " ++ Natural.toString (Natural.sub Natural.zero Natural.five)) ]
            ]
        ]


radioButton : String -> Bool -> msg -> String -> Html msg
radioButton groupName isChecked msg label =
    Html.label []
        [ input
            [ type_ "radio"
            , name groupName
            , checked isChecked
            , onClick msg
            ]
            []
        , text (" " ++ label)
        ]
