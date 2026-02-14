port module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Decode as Decode
import Translations exposing (I18n, Language(..))



-- PORTS


port setLang : String -> Cmd msg



-- MAIN


main : Program Decode.Value Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view
        }



-- MODEL


type alias Model =
    { i18n : I18n
    , name : String
    }


init : Decode.Value -> ( Model, Cmd Msg )
init flagsValue =
    let
        browserLanguages =
            flagsValue
                |> Decode.decodeValue
                    (Decode.field "languages" (Decode.list Decode.string))
                |> Result.withDefault []

        lang =
            detectLanguage browserLanguages
    in
    ( { i18n = Translations.init lang
      , name = ""
      }
    , setLang (Translations.languageToString lang)
    )


detectLanguage : List String -> Language
detectLanguage browserLanguages =
    case browserLanguages of
        [] ->
            En

        tag :: rest ->
            case Translations.languageFromString tag of
                Just lang ->
                    lang

                Nothing ->
                    detectLanguage rest



-- UPDATE


type Msg
    = SwitchLanguage Language
    | SetName String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SwitchLanguage lang ->
            ( { model | i18n = Translations.init lang }
            , setLang (Translations.languageToString lang)
            )

        SetName name ->
            ( { model | name = name }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    let
        currentLang =
            Translations.currentLanguage model.i18n
    in
    div []
        [ h1 [] [ text (Translations.welcome model.i18n) ]
        , p [] [ text (Translations.description model.i18n) ]
        , viewLanguageSwitcher currentLang model.i18n
        , viewNameInput model
        ]


viewLanguageSwitcher : Language -> I18n -> Html Msg
viewLanguageSwitcher currentLang i18n =
    p []
        [ text (Translations.language i18n)
        , text ": "
        , button
            [ onClick (SwitchLanguage En)
            , disabled (currentLang == En)
            ]
            [ text "🇬🇧" ]
        , text " "
        , button
            [ onClick (SwitchLanguage Fr)
            , disabled (currentLang == Fr)
            ]
            [ text "🇫🇷" ]
        ]


viewNameInput : Model -> Html Msg
viewNameInput model =
    div []
        [ input
            [ type_ "text"
            , value model.name
            , onInput SetName
            , placeholder "name"
            ]
            []
        , if String.isEmpty model.name then
            text ""

          else
            p [] [ text (Translations.greeting model.name model.i18n) ]
        ]
