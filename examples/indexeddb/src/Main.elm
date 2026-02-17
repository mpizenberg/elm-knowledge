port module Main exposing (main)

import Browser
import ConcurrentTask exposing (ConcurrentTask)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import IndexedDb as Idb
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



-- SCHEMA


type alias Todo =
    { id : Int
    , text : String
    , done : Bool
    }


{-| InlineKey store — key extracted from the value's "id" field.
-}
todosStore : Idb.Store Idb.InlineKey
todosStore =
    Idb.defineStore "todos"
        |> Idb.withKeyPath "id"


appSchema : Idb.Schema
appSchema =
    Idb.schema "todo-example" 1
        |> Idb.withStore todosStore



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


{-| Open the database, then load all todos.
Demonstrates: open, andThen, getAll
-}
loadApp : ConcurrentTask Idb.Error ( Idb.Db, List Todo )
loadApp =
    Idb.open appSchema
        |> ConcurrentTask.andThen
            (\db ->
                Idb.getAll db todosStore todoDecoder
                    |> ConcurrentTask.map (\todos -> ( db, todos ))
            )


{-| Insert a new todo (fails with AlreadyExists if id exists).
Demonstrates: add
-}
addTodoTask : Idb.Db -> Todo -> ConcurrentTask Idb.Error ()
addTodoTask db todo =
    Idb.add db todosStore (encodeTodo todo)
        |> ConcurrentTask.return ()


{-| Upsert a toggled todo.
Demonstrates: put
-}
toggleTodoTask : Idb.Db -> Todo -> ConcurrentTask Idb.Error ()
toggleTodoTask db todo =
    Idb.put db todosStore (encodeTodo { todo | done = not todo.done })
        |> ConcurrentTask.return ()


{-| Delete a single todo by key.
Demonstrates: delete
-}
deleteTodoTask : Idb.Db -> Int -> ConcurrentTask Idb.Error ()
deleteTodoTask db id =
    Idb.delete db todosStore (Idb.IntKey id)


{-| Delete all completed todos in one transaction.
Demonstrates: deleteMany
-}
deleteCompletedTask : Idb.Db -> List Todo -> ConcurrentTask Idb.Error ()
deleteCompletedTask db todos =
    todos
        |> List.filter .done
        |> List.map (\t -> Idb.IntKey t.id)
        |> Idb.deleteMany db todosStore



-- MODEL


type alias Model =
    { tasks : ConcurrentTask.Pool Msg
    , db : Maybe Idb.Db
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
    | DeleteCompleted
    | GotLoad (ConcurrentTask.Response Idb.Error ( Idb.Db, List Todo ))
    | GotWrite (ConcurrentTask.Response Idb.Error ())
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
                                    (addTodoTask db todo)
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
                    case List.filter (\t -> t.id == id) model.todos |> List.head of
                        Just todo ->
                            let
                                ( tasks, cmd ) =
                                    ConcurrentTask.attempt
                                        { send = send
                                        , pool = model.tasks
                                        , onComplete = GotWrite
                                        }
                                        (toggleTodoTask db todo)

                                updatedTodos =
                                    List.map
                                        (\t ->
                                            if t.id == id then
                                                { t | done = not t.done }

                                            else
                                                t
                                        )
                                        model.todos
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
                                (deleteTodoTask db id)
                    in
                    ( { model
                        | tasks = tasks
                        , todos = List.filter (\t -> t.id /= id) model.todos
                      }
                    , cmd
                    )

                Nothing ->
                    ( model, Cmd.none )

        DeleteCompleted ->
            case model.db of
                Just db ->
                    let
                        ( tasks, cmd ) =
                            ConcurrentTask.attempt
                                { send = send
                                , pool = model.tasks
                                , onComplete = GotWrite
                                }
                                (deleteCompletedTask db model.todos)
                    in
                    ( { model
                        | tasks = tasks
                        , todos = List.filter (\t -> not t.done) model.todos
                      }
                    , cmd
                    )

                Nothing ->
                    ( model, Cmd.none )

        GotLoad response ->
            case response of
                ConcurrentTask.Success ( db, todos ) ->
                    let
                        maxId =
                            List.map .id todos
                                |> List.maximum
                                |> Maybe.withDefault 0
                    in
                    ( { model
                        | db = Just db
                        , todos = todos
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


errorToString : Idb.Error -> String
errorToString err =
    case err of
        Idb.AlreadyExists ->
            "Record already exists"

        Idb.TransactionError msg_ ->
            "Transaction error: " ++ msg_

        Idb.QuotaExceeded ->
            "Storage quota exceeded"

        Idb.DatabaseError msg_ ->
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
        , style "padding" "20px"
        ]
        [ h1 [] [ text "Todo List" ]
        , p [] [ text "Persisted in IndexedDB via elm-indexeddb." ]
        , case model.status of
            Loading ->
                p [ style "color" "#888" ] [ text "Opening database..." ]

            Error message ->
                p [ style "color" "red" ] [ text ("Error: " ++ message) ]

            Ready ->
                div []
                    [ viewAddForm model
                    , viewTodos model.todos
                    , viewFooter model.todos
                    ]
        ]


viewAddForm : Model -> Html Msg
viewAddForm model =
    Html.form
        [ onSubmit AddTodo
        , style "display" "flex"
        , style "gap" "8px"
        , style "margin-bottom" "16px"
        ]
        [ Html.input
            [ type_ "text"
            , placeholder "What needs to be done?"
            , value model.input
            , onInput UpdateInput
            , style "flex" "1"
            , style "padding" "8px"
            , style "border" "1px solid #ccc"
            , style "border-radius" "4px"
            ]
            []
        , button [ type_ "submit", style "padding" "8px 16px" ] [ text "Add" ]
        ]


viewTodos : List Todo -> Html Msg
viewTodos todos =
    if List.isEmpty todos then
        p [ style "color" "#888" ] [ text "No todos yet. Add one above!" ]

    else
        ul [ style "list-style" "none", style "padding" "0" ]
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
            , style "opacity"
                (if todo.done then
                    "0.5"

                 else
                    "1"
                )
            ]
            [ text todo.text ]
        , button
            [ onClick (DeleteTodo todo.id)
            , style "border" "none"
            , style "background" "none"
            , style "color" "#c00"
            , style "cursor" "pointer"
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

            completed =
                List.filter .done todos |> List.length
        in
        div
            [ style "display" "flex"
            , style "justify-content" "space-between"
            , style "align-items" "center"
            , style "margin-top" "12px"
            , style "font-size" "14px"
            , style "color" "#888"
            ]
            [ span []
                [ text
                    (String.fromInt remaining
                        ++ " of "
                        ++ String.fromInt (List.length todos)
                        ++ " remaining"
                    )
                ]
            , if completed > 0 then
                button
                    [ onClick DeleteCompleted
                    , style "padding" "4px 10px"
                    , style "font-size" "13px"
                    , style "cursor" "pointer"
                    ]
                    [ text ("Delete completed (" ++ String.fromInt completed ++ ")") ]

              else
                text ""
            ]
