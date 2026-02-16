port module Main exposing (main)

import Browser
import ConcurrentTask exposing (ConcurrentTask)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import IndexedDb
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



-- STORES


type alias Todo =
    { id : Int
    , text : String
    , done : Bool
    }


todosStore : IndexedDb.Store IndexedDb.InlineKey
todosStore =
    IndexedDb.defineStore "todos"
        |> IndexedDb.withKeyPath "id"


appSchema : IndexedDb.Schema
appSchema =
    IndexedDb.schema "todoapp" 1
        |> IndexedDb.withStore todosStore



-- ENCODERS / DECODERS


todoDecoder : Decode.Decoder Todo
todoDecoder =
    Decode.map3 Todo
        (Decode.field "id" Decode.int)
        (Decode.field "text" Decode.string)
        (Decode.field "done" Decode.bool)


encodeTodo : Todo -> Encode.Value
encodeTodo todo =
    Encode.object
        [ ( "id", Encode.int todo.id )
        , ( "text", Encode.string todo.text )
        , ( "done", Encode.bool todo.done )
        ]



-- TASKS


type alias AppData =
    { db : IndexedDb.Db
    , todos : List Todo
    }


loadApp : ConcurrentTask IndexedDb.Error AppData
loadApp =
    IndexedDb.open appSchema
        |> ConcurrentTask.andThen
            (\db ->
                IndexedDb.getAll db todosStore todoDecoder
                    |> ConcurrentTask.map (\todos -> { db = db, todos = todos })
            )


saveTodo : IndexedDb.Db -> Todo -> ConcurrentTask IndexedDb.Error ()
saveTodo db todo =
    IndexedDb.put db todosStore (encodeTodo todo)
        |> ConcurrentTask.return ()



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


type alias Model =
    { tasks : ConcurrentTask.Pool Msg
    , db : Maybe IndexedDb.Db
    , todos : List Todo
    , nextId : Int
    , input : String
    , status : Status
    }


type Status
    = Loading
    | Ready
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
                loadApp
    in
    ( { tasks = tasks
      , db = Nothing
      , todos = []
      , nextId = 1
      , input = ""
      , status = Loading
      }
    , cmd
    )



-- UPDATE


type Msg
    = UpdateInput String
    | AddTodo
    | ToggleTodo Int
    | DeleteTodo Int
    | ClearAll
    | GotLoad (ConcurrentTask.Response IndexedDb.Error AppData)
    | GotWrite (ConcurrentTask.Response IndexedDb.Error ())
    | OnProgress ( ConcurrentTask.Pool Msg, Cmd Msg )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateInput text ->
            ( { model | input = text }, Cmd.none )

        AddTodo ->
            case model.db of
                Just db ->
                    if String.trim model.input /= "" then
                        let
                            todo =
                                { id = model.nextId
                                , text = String.trim model.input
                                , done = False
                                }

                            ( tasks, cmd ) =
                                ConcurrentTask.attempt
                                    { send = send
                                    , pool = model.tasks
                                    , onComplete = GotWrite
                                    }
                                    (saveTodo db todo)
                        in
                        ( { model
                            | tasks = tasks
                            , todos = model.todos ++ [ todo ]
                            , nextId = model.nextId + 1
                            , input = ""
                          }
                        , cmd
                        )

                    else
                        ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        ToggleTodo id ->
            case model.db of
                Just db ->
                    let
                        updatedTodos =
                            List.map
                                (\t ->
                                    if t.id == id then
                                        { t | done = not t.done }

                                    else
                                        t
                                )
                                model.todos

                        maybeTodo =
                            List.filter (\t -> t.id == id) updatedTodos
                                |> List.head
                    in
                    case maybeTodo of
                        Just todo ->
                            let
                                ( tasks, cmd ) =
                                    ConcurrentTask.attempt
                                        { send = send
                                        , pool = model.tasks
                                        , onComplete = GotWrite
                                        }
                                        (saveTodo db todo)
                            in
                            ( { model | tasks = tasks, todos = updatedTodos }, cmd )

                        Nothing ->
                            ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        DeleteTodo id ->
            case model.db of
                Just db ->
                    let
                        ( tasks, cmd ) =
                            ConcurrentTask.attempt
                                { send = send
                                , pool = model.tasks
                                , onComplete = GotWrite
                                }
                                (IndexedDb.delete db todosStore (IndexedDb.IntKey id))
                    in
                    ( { model
                        | tasks = tasks
                        , todos = List.filter (\t -> t.id /= id) model.todos
                      }
                    , cmd
                    )

                Nothing ->
                    ( model, Cmd.none )

        ClearAll ->
            case model.db of
                Just db ->
                    let
                        ( tasks, cmd ) =
                            ConcurrentTask.attempt
                                { send = send
                                , pool = model.tasks
                                , onComplete = GotWrite
                                }
                                (IndexedDb.clear db todosStore)
                    in
                    ( { model | tasks = tasks, todos = [], nextId = 1 }, cmd )

                Nothing ->
                    ( model, Cmd.none )

        GotLoad response ->
            case response of
                ConcurrentTask.Success data ->
                    let
                        maxId =
                            List.map .id data.todos
                                |> List.maximum
                                |> Maybe.withDefault 0
                    in
                    ( { model
                        | db = Just data.db
                        , todos = data.todos
                        , nextId = maxId + 1
                        , status = Ready
                      }
                    , Cmd.none
                    )

                ConcurrentTask.Error err ->
                    ( { model | status = Error (errorToString err) }, Cmd.none )

                ConcurrentTask.UnexpectedError err ->
                    ( { model | status = Error (unexpectedErrorToString err) }, Cmd.none )

        GotWrite response ->
            case response of
                ConcurrentTask.Success _ ->
                    ( model, Cmd.none )

                ConcurrentTask.Error err ->
                    ( { model | status = Error (errorToString err) }, Cmd.none )

                ConcurrentTask.UnexpectedError err ->
                    ( { model | status = Error (unexpectedErrorToString err) }, Cmd.none )

        OnProgress ( tasks, cmd ) ->
            ( { model | tasks = tasks }, cmd )


errorToString : IndexedDb.Error -> String
errorToString err =
    case err of
        IndexedDb.AlreadyExists ->
            "Record already exists"

        IndexedDb.TransactionError msg_ ->
            "Transaction error: " ++ msg_

        IndexedDb.QuotaExceeded ->
            "Storage quota exceeded"

        IndexedDb.DatabaseError msg_ ->
            "Database error: " ++ msg_


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
    div
        [ style "font-family" "sans-serif"
        , style "max-width" "480px"
        , style "margin" "40px auto"
        , style "padding" "0 20px"
        ]
        [ h1 [] [ text "Todo List" ]
        , p [] [ text "Persisted in IndexedDB via elm-indexeddb + elm-concurrent-task." ]
        , case model.status of
            Loading ->
                p [ style "color" "#888" ] [ text "Opening database..." ]

            Error message ->
                p [ style "color" "red" ] [ text ("Error: " ++ message) ]

            Ready ->
                div []
                    [ viewAddForm model.input
                    , viewTodos model.todos
                    , viewFooter model.todos
                    ]
        ]


viewAddForm : String -> Html Msg
viewAddForm input_ =
    Html.form
        [ onSubmit AddTodo
        , style "display" "flex"
        , style "gap" "8px"
        , style "margin-bottom" "16px"
        ]
        [ Html.input
            [ type_ "text"
            , placeholder "What needs to be done?"
            , value input_
            , onInput UpdateInput
            , style "flex" "1"
            , style "padding" "8px"
            ]
            []
        , button [ type_ "submit", style "padding" "8px 16px" ] [ text "Add" ]
        ]


viewTodos : List Todo -> Html Msg
viewTodos todos =
    if List.isEmpty todos then
        p [ style "color" "#888" ] [ text "No todos yet. Add one above!" ]

    else
        ul [ style "list-style" "none", style "padding" "0", style "margin" "0" ]
            (List.map viewTodo todos)


viewTodo : Todo -> Html Msg
viewTodo todo =
    li
        [ style "display" "flex"
        , style "align-items" "center"
        , style "gap" "8px"
        , style "padding" "8px 0"
        , style "border-bottom" "1px solid #eee"
        ]
        [ Html.input
            [ type_ "checkbox"
            , checked todo.done
            , onClick (ToggleTodo todo.id)
            , style "cursor" "pointer"
            ]
            []
        , span
            [ style "flex" "1"
            , style "text-decoration"
                (if todo.done then
                    "line-through"

                 else
                    "none"
                )
            , style "color"
                (if todo.done then
                    "#888"

                 else
                    "inherit"
                )
            ]
            [ text todo.text ]
        , button
            [ onClick (DeleteTodo todo.id)
            , style "padding" "2px 8px"
            , style "color" "#c00"
            , style "cursor" "pointer"
            , style "border" "none"
            , style "background" "none"
            ]
            [ text "x" ]
        ]


viewFooter : List Todo -> Html Msg
viewFooter todos =
    if List.isEmpty todos then
        text ""

    else
        let
            remaining =
                List.filter (\t -> not t.done) todos |> List.length

            total =
                List.length todos
        in
        div [ style "display" "flex", style "justify-content" "space-between", style "align-items" "center", style "margin-top" "12px", style "color" "#666" ]
            [ span []
                [ text
                    (String.fromInt remaining
                        ++ " of "
                        ++ String.fromInt total
                        ++ " remaining"
                    )
                ]
            , button
                [ onClick ClearAll
                , style "padding" "6px 12px"
                , style "color" "#c00"
                , style "cursor" "pointer"
                ]
                [ text "Clear all" ]
            ]
