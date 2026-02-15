module Main exposing (main)

import Browser
import Dict.Any exposing (AnyDict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)



-- MAIN


main : Program () Model Msg
main =
    Browser.sandbox
        { init = init
        , update = update
        , view = view
        }



-- FRUIT TYPE


type Fruit
    = Apple
    | Banana
    | Orange
    | Mango


fruitToString : Fruit -> String
fruitToString fruit =
    case fruit of
        Apple ->
            "Apple"

        Banana ->
            "Banana"

        Orange ->
            "Orange"

        Mango ->
            "Mango"


allFruits : List Fruit
allFruits =
    [ Apple, Banana, Orange, Mango ]



-- MODEL


type alias Model =
    { inventory : AnyDict String Fruit Int
    , selected : Fruit
    }


init : Model
init =
    { inventory = Dict.Any.empty fruitToString
    , selected = Apple
    }



-- UPDATE


type Msg
    = SelectFruit Fruit
    | AddOne
    | RemoveOne
    | ClearFruit


update : Msg -> Model -> Model
update msg model =
    case msg of
        SelectFruit fruit ->
            { model | selected = fruit }

        AddOne ->
            { model
                | inventory =
                    Dict.Any.update model.selected
                        (\existing ->
                            case existing of
                                Just n ->
                                    Just (n + 1)

                                Nothing ->
                                    Just 1
                        )
                        model.inventory
            }

        RemoveOne ->
            { model
                | inventory =
                    Dict.Any.update model.selected
                        (\existing ->
                            case existing of
                                Just n ->
                                    if n > 1 then
                                        Just (n - 1)

                                    else
                                        Nothing

                                Nothing ->
                                    Nothing
                        )
                        model.inventory
            }

        ClearFruit ->
            { model
                | inventory = Dict.Any.remove model.selected model.inventory
            }



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Fruit Inventory" ]
        , p [] [ text "Uses AnyDict with a custom Fruit union type as keys." ]
        , viewSelector model.selected
        , viewActions
        , viewInventory model.inventory
        ]


viewSelector : Fruit -> Html Msg
viewSelector selected =
    p []
        (text "Select fruit: "
            :: List.intersperse (text " ")
                (List.map
                    (\fruit ->
                        label []
                            [ input
                                [ type_ "radio"
                                , name "fruit"
                                , checked (fruit == selected)
                                , onClick (SelectFruit fruit)
                                ]
                                []
                            , text (" " ++ fruitToString fruit)
                            ]
                    )
                    allFruits
                )
        )


viewActions : Html Msg
viewActions =
    p []
        [ button [ onClick AddOne ] [ text "+1" ]
        , text " "
        , button [ onClick RemoveOne ] [ text "-1" ]
        , text " "
        , button [ onClick ClearFruit ] [ text "Remove" ]
        ]


viewInventory : AnyDict String Fruit Int -> Html Msg
viewInventory inventory =
    let
        items =
            Dict.Any.toList inventory

        total =
            List.foldl (\( _, qty ) acc -> acc + qty) 0 items
    in
    div []
        [ h2 [] [ text "Current Inventory" ]
        , if List.isEmpty items then
            p [] [ text "No fruit in inventory. Select a fruit and click +1." ]

          else
            table []
                [ thead []
                    [ tr []
                        [ th [ style "text-align" "left", style "padding-right" "2em" ] [ text "Fruit" ]
                        , th [ style "text-align" "right" ] [ text "Quantity" ]
                        ]
                    ]
                , tbody []
                    (List.map
                        (\( fruit, qty ) ->
                            tr []
                                [ td [ style "padding-right" "2em" ] [ text (fruitToString fruit) ]
                                , td [ style "text-align" "right" ] [ text (String.fromInt qty) ]
                                ]
                        )
                        items
                    )
                , tfoot []
                    [ tr []
                        [ td [ style "padding-right" "2em" ] [ strong [] [ text "Total" ] ]
                        , td [ style "text-align" "right" ] [ strong [] [ text (String.fromInt total) ] ]
                        ]
                    ]
                ]
        ]
