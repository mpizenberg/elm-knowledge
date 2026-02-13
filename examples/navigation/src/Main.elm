port module Main exposing (main)

import AppUrl exposing (AppUrl)
import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Decode as Decode
import Json.Encode as Encode
import Url


port navigationOut : Encode.Value -> Cmd msg


port onNavigation : (Decode.Value -> msg) -> Sub msg


pushUrl : String -> Cmd msg
pushUrl url =
    navigationOut
        (Encode.object
            [ ( "tag", Encode.string "pushUrl" )
            , ( "url", Encode.string url )
            ]
        )


pushWizardStep : Int -> Cmd msg
pushWizardStep step =
    navigationOut
        (Encode.object
            [ ( "tag", Encode.string "pushState" )
            , ( "state"
              , Encode.object
                    [ ( "wizardStep", Encode.int step ) ]
              )
            ]
        )


replaceUrl : String -> Cmd msg
replaceUrl url =
    navigationOut
        (Encode.object
            [ ( "tag", Encode.string "replaceUrl" )
            , ( "url", Encode.string url )
            ]
        )



-- MAIN


main : Program String Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type Page
    = Home
    | Wizard WizardStep
    | About
    | NotFound


type WizardStep
    = Step1
    | Step2
    | Step3


type alias WizardData =
    { name : String
    , color : String
    }


type alias Model =
    { page : Page
    , wizardData : WizardData
    , counter : Int
    }


init : String -> ( Model, Cmd Msg )
init locationHref =
    ( { page = parseUrl locationHref
      , wizardData = { name = "", color = "" }
      , counter = 0
      }
    , Cmd.none
    )



-- ROUTING


parseUrl : String -> Page
parseUrl locationHref =
    case Url.fromString locationHref of
        Nothing ->
            NotFound

        Just url ->
            let
                appUrl =
                    AppUrl.fromUrl url
            in
            case appUrl.path of
                [] ->
                    Home

                [ "wizard" ] ->
                    Wizard Step1

                [ "about" ] ->
                    About

                _ ->
                    NotFound



-- NAVIGATION DECODER


type alias NavData =
    { href : String
    , wizardStep : Maybe Int
    }


decodeNavigation : Decode.Value -> Maybe NavData
decodeNavigation value =
    Decode.decodeValue
        (Decode.map2 NavData
            (Decode.field "href" Decode.string)
            (Decode.maybe (Decode.at [ "state", "wizardStep" ] Decode.int))
        )
        value
        |> Result.toMaybe



-- UPDATE


type Msg
    = NavigationChanged Decode.Value
    | NavigateTo String
    | GoToWizardStep WizardStep
    | IncrementCounter
    | SetName String
    | SetColor String


wizardStepToInt : WizardStep -> Int
wizardStepToInt step =
    case step of
        Step1 ->
            1

        Step2 ->
            2

        Step3 ->
            3


intToWizardStep : Int -> WizardStep
intToWizardStep n =
    case n of
        2 ->
            Step2

        3 ->
            Step3

        _ ->
            Step1


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NavigateTo url ->
            ( model, pushUrl url )

        NavigationChanged value ->
            case decodeNavigation value of
                Just nav ->
                    let
                        page =
                            parseUrl nav.href

                        adjusted =
                            case ( page, nav.wizardStep ) of
                                ( Wizard _, Just step ) ->
                                    Wizard (intToWizardStep step)

                                _ ->
                                    page
                    in
                    ( { model | page = adjusted }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        GoToWizardStep step ->
            ( model, pushWizardStep (wizardStepToInt step) )

        IncrementCounter ->
            let
                newCounter =
                    model.counter + 1
            in
            ( { model | counter = newCounter }
            , replaceUrl ("/about#" ++ String.fromInt newCounter)
            )

        SetName name ->
            let
                data =
                    model.wizardData
            in
            ( { model | wizardData = { data | name = name } }, Cmd.none )

        SetColor color ->
            let
                data =
                    model.wizardData
            in
            ( { model | wizardData = { data | color = color } }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    onNavigation NavigationChanged



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ viewNav
        , viewPage model
        ]


viewNav : Html Msg
viewNav =
    nav []
        [ navLink "/" "Home"
        , text " | "
        , navLink "/wizard" "Wizard"
        , text " | "
        , navLink "/about" "About"
        ]


navLink : String -> String -> Html Msg
navLink url label =
    a [ href url, onClickPreventDefault (NavigateTo url) ] [ text label ]


onClickPreventDefault : msg -> Attribute msg
onClickPreventDefault msg =
    Html.Events.preventDefaultOn "click"
        (Decode.succeed ( msg, True ))


viewPage : Model -> Html Msg
viewPage model =
    case model.page of
        Home ->
            viewHome

        Wizard step ->
            viewWizard step model.wizardData

        About ->
            viewAbout model.counter

        NotFound ->
            h2 [] [ text "Page not found" ]


viewHome : Html Msg
viewHome =
    div []
        [ h1 [] [ text "Home" ]
        , p [] [ text "Welcome! This is a minimal Elm SPA using Browser.element with port-based URL navigation." ]
        , p [] [ text "Try the Wizard to see multi-step navigation with browser back button support." ]
        ]


viewWizard : WizardStep -> WizardData -> Html Msg
viewWizard step data =
    case step of
        Step1 ->
            div []
                [ h1 [] [ text "Wizard - Step 1" ]
                , p [] [ text "What is your name?" ]
                , input [ type_ "text", value data.name, onInput SetName, placeholder "Enter your name" ] []
                , p []
                    [ button [ onClick (GoToWizardStep Step2) ] [ text "Next \u{2192}" ]
                    ]
                ]

        Step2 ->
            div []
                [ h1 [] [ text "Wizard - Step 2" ]
                , p [] [ text "Pick a color:" ]
                , label []
                    [ input [ type_ "radio", name "color", value "red", checked (data.color == "red"), onInput SetColor ] []
                    , text " Red"
                    ]
                , label []
                    [ input [ type_ "radio", name "color", value "green", checked (data.color == "green"), onInput SetColor ] []
                    , text " Green"
                    ]
                , label []
                    [ input [ type_ "radio", name "color", value "blue", checked (data.color == "blue"), onInput SetColor ] []
                    , text " Blue"
                    ]
                , p []
                    [ button [ onClick (GoToWizardStep Step1) ] [ text "\u{2190} Back" ]
                    , text " | "
                    , button [ onClick (GoToWizardStep Step3) ] [ text "Next \u{2192}" ]
                    ]
                ]

        Step3 ->
            div []
                [ h1 [] [ text "Wizard - Step 3" ]
                , p [] [ text "Summary:" ]
                , ul []
                    [ li [] [ text ("Name: " ++ data.name) ]
                    , li [] [ text ("Color: " ++ data.color) ]
                    ]
                , p []
                    [ button [ onClick (GoToWizardStep Step2) ] [ text "\u{2190} Back" ]
                    , text " | "
                    , button [ onClick (GoToWizardStep Step1) ] [ text "Start Over" ]
                    ]
                ]


viewAbout : Int -> Html Msg
viewAbout counter =
    div []
        [ h1 [] [ text "About" ]
        , p [] [ text "This app demonstrates port-based URL navigation with Browser.element and the lydell/elm-app-url package." ]
        , p []
            [ text ("Counter: " ++ String.fromInt counter ++ " ")
            , button [ onClick IncrementCounter ] [ text "+1" ]
            ]
        , p [] [ text "The URL updates via replaceState without triggering a page update. The model is the source of truth." ]
        ]
