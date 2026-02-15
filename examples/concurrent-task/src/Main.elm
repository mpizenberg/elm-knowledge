port module Main exposing (main)

import Browser
import ConcurrentTask exposing (ConcurrentTask)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Decode as Decode
import Json.Encode as Encode



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- PORTS


port send : Decode.Value -> Cmd msg


port receive : (Decode.Value -> msg) -> Sub msg



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    ConcurrentTask.onProgress
        { send = send
        , receive = receive
        , onProgress = OnProgress
        }
        model.tasks



-- MODEL


type alias Profile =
    { name : String
    , color : String
    }


type alias Model =
    { tasks : ConcurrentTask.Pool Msg
    , nameInput : String
    , colorInput : String
    , stored : Maybe Profile
    , status : Status
    }


type Status
    = Idle
    | Loading
    | Saved
    | Error String


init : () -> ( Model, Cmd Msg )
init _ =
    let
        ( tasks, cmd ) =
            ConcurrentTask.attempt
                { send = send
                , pool = ConcurrentTask.pool
                , onComplete = GotLoad
                }
                loadProfile
    in
    ( { tasks = tasks
      , nameInput = ""
      , colorInput = ""
      , stored = Nothing
      , status = Loading
      }
    , cmd
    )



-- TASKS


type LoadError
    = NoValue
    | ReadBlocked


loadProfile : ConcurrentTask LoadError Profile
loadProfile =
    ConcurrentTask.map2 Profile
        (getItem "profile:name")
        (getItem "profile:color")


saveProfile : Profile -> ConcurrentTask Never ()
saveProfile profile =
    ConcurrentTask.batch
        [ setItem "profile:name" profile.name
        , setItem "profile:color" profile.color
        ]
        |> ConcurrentTask.return ()


getItem : String -> ConcurrentTask LoadError String
getItem key =
    ConcurrentTask.define
        { function = "localstorage:getItem"
        , expect = ConcurrentTask.expectString
        , errors = ConcurrentTask.expectErrors decodeLoadError
        , args = Encode.object [ ( "key", Encode.string key ) ]
        }


decodeLoadError : Decode.Decoder LoadError
decodeLoadError =
    Decode.string
        |> Decode.andThen
            (\err ->
                case err of
                    "NO_VALUE" ->
                        Decode.succeed NoValue

                    "READ_BLOCKED" ->
                        Decode.succeed ReadBlocked

                    _ ->
                        Decode.fail ("Unknown error: " ++ err)
            )


setItem : String -> String -> ConcurrentTask Never ()
setItem key value =
    ConcurrentTask.define
        { function = "localstorage:setItem"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectNoErrors
        , args =
            Encode.object
                [ ( "key", Encode.string key )
                , ( "value", Encode.string value )
                ]
        }



-- UPDATE


type Msg
    = UpdateName String
    | UpdateColor String
    | Save
    | GotLoad (ConcurrentTask.Response LoadError Profile)
    | GotSave (ConcurrentTask.Response Never ())
    | OnProgress ( ConcurrentTask.Pool Msg, Cmd Msg )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateName name ->
            ( { model | nameInput = name }, Cmd.none )

        UpdateColor color ->
            ( { model | colorInput = color }, Cmd.none )

        Save ->
            let
                profile =
                    { name = model.nameInput, color = model.colorInput }

                ( tasks, cmd ) =
                    ConcurrentTask.attempt
                        { send = send
                        , pool = model.tasks
                        , onComplete = GotSave
                        }
                        (saveProfile profile)
            in
            ( { model | tasks = tasks, status = Loading }, cmd )

        GotLoad response ->
            case response of
                ConcurrentTask.Success profile ->
                    ( { model
                        | nameInput = profile.name
                        , colorInput = profile.color
                        , stored = Just profile
                        , status = Idle
                      }
                    , Cmd.none
                    )

                ConcurrentTask.Error _ ->
                    -- No saved profile yet, start with defaults
                    ( { model
                        | nameInput = "Elm Developer"
                        , colorInput = "#60b5cc"
                        , status = Idle
                      }
                    , Cmd.none
                    )

                ConcurrentTask.UnexpectedError err ->
                    ( { model | status = Error (unexpectedErrorToString err) }
                    , Cmd.none
                    )

        GotSave response ->
            case response of
                ConcurrentTask.Success _ ->
                    ( { model
                        | stored = Just { name = model.nameInput, color = model.colorInput }
                        , status = Saved
                      }
                    , Cmd.none
                    )

                ConcurrentTask.Error never_ ->
                    never never_

                ConcurrentTask.UnexpectedError err ->
                    ( { model | status = Error (unexpectedErrorToString err) }
                    , Cmd.none
                    )

        OnProgress ( tasks, cmd ) ->
            ( { model | tasks = tasks }, cmd )


unexpectedErrorToString : ConcurrentTask.UnexpectedError -> String
unexpectedErrorToString err =
    case err of
        ConcurrentTask.MissingFunction name ->
            "Missing JS function: " ++ name

        ConcurrentTask.ResponseDecoderFailure { function } ->
            "Response decoder failed for: " ++ function

        ConcurrentTask.ErrorsDecoderFailure { function } ->
            "Error decoder failed for: " ++ function

        ConcurrentTask.UnhandledJsException { function, message } ->
            function ++ " threw: " ++ message

        ConcurrentTask.InternalError message ->
            "Internal error: " ++ message



-- VIEW


view : Model -> Html Msg
view model =
    div [ style "font-family" "sans-serif", style "max-width" "480px", style "margin" "40px auto", style "padding" "0 20px" ]
        [ h1 [] [ text "Profile Editor" ]
        , p [] [ text "Edit your profile. Values are stored in localStorage using elm-concurrent-task." ]
        , viewForm model
        , viewStored model.stored
        , viewStatus model.status
        ]


viewForm : Model -> Html Msg
viewForm model =
    div []
        [ div [ style "margin-bottom" "12px" ]
            [ label [ style "display" "block", style "margin-bottom" "4px" ] [ text "Name" ]
            , input [ type_ "text", value model.nameInput, onInput UpdateName, style "width" "100%", style "padding" "8px", style "box-sizing" "border-box" ] []
            ]
        , div [ style "margin-bottom" "12px" ]
            [ label [ style "display" "block", style "margin-bottom" "4px" ] [ text "Favorite color" ]
            , div [ style "display" "flex", style "gap" "8px", style "align-items" "center" ]
                [ input [ type_ "color", value model.colorInput, onInput UpdateColor ] []
                , span [] [ text model.colorInput ]
                ]
            ]
        , button [ onClick Save, style "padding" "8px 20px" ] [ text "Save" ]
        ]


viewStored : Maybe Profile -> Html Msg
viewStored maybeProfile =
    case maybeProfile of
        Nothing ->
            p [ style "color" "#888" ] [ text "No saved profile yet." ]

        Just profile ->
            div [ style "margin-top" "20px", style "padding" "12px", style "border" "1px solid #ddd", style "border-radius" "4px" ]
                [ h3 [ style "margin-top" "0" ] [ text "Stored in localStorage" ]
                , p [] [ text ("Name: " ++ profile.name) ]
                , p []
                    [ text "Color: "
                    , span
                        [ style "display" "inline-block"
                        , style "width" "16px"
                        , style "height" "16px"
                        , style "background-color" profile.color
                        , style "vertical-align" "middle"
                        , style "border-radius" "2px"
                        , style "margin-right" "4px"
                        ]
                        []
                    , text profile.color
                    ]
                ]


viewStatus : Status -> Html Msg
viewStatus status =
    case status of
        Idle ->
            text ""

        Loading ->
            p [ style "color" "#888" ] [ text "Loading..." ]

        Saved ->
            p [ style "color" "green" ] [ text "Saved!" ]

        Error message ->
            p [ style "color" "red" ] [ text ("Error: " ++ message) ]
