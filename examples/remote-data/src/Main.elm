module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode
import RemoteData exposing (RemoteData(..), WebData)



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


type alias Post =
    { id : Int
    , title : String
    , body : String
    }


type alias Model =
    { posts : WebData (List Post)
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { posts = NotAsked }
    , Cmd.none
    )



-- UPDATE


type Msg
    = FetchPosts
    | GotPosts (WebData (List Post))


postDecoder : Decode.Decoder Post
postDecoder =
    Decode.map3 Post
        (Decode.field "id" Decode.int)
        (Decode.field "title" Decode.string)
        (Decode.field "body" Decode.string)


fetchPosts : Cmd Msg
fetchPosts =
    Http.get
        { url = "https://jsonplaceholder.typicode.com/posts"
        , expect =
            Http.expectJson
                (RemoteData.fromResult >> GotPosts)
                (Decode.list postDecoder)
        }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchPosts ->
            ( { model | posts = Loading }
            , fetchPosts
            )

        GotPosts response ->
            ( { model | posts = response }
            , Cmd.none
            )



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Remote Data Example" ]
        , p [] [ text "Fetches posts from JSONPlaceholder, demonstrating all 4 RemoteData states." ]
        , viewPosts model.posts
        ]


viewPosts : WebData (List Post) -> Html Msg
viewPosts posts =
    case posts of
        NotAsked ->
            div []
                [ p [] [ text "Posts not yet requested." ]
                , button [ onClick FetchPosts ] [ text "Load Posts" ]
                ]

        Loading ->
            p [] [ text "Loading..." ]

        Failure error ->
            div []
                [ p [ style "color" "red" ]
                    [ text ("Error: " ++ httpErrorToString error) ]
                , button [ onClick FetchPosts ] [ text "Retry" ]
                ]

        Success postList ->
            div []
                [ p []
                    [ text (String.fromInt (List.length postList) ++ " posts loaded. ")
                    , button [ onClick FetchPosts ] [ text "Reload" ]
                    ]
                , ul [] (List.map viewPost (List.take 10 postList))
                ]


viewPost : Post -> Html Msg
viewPost post =
    li []
        [ strong [] [ text (String.fromInt post.id ++ ". " ++ post.title) ]
        , p [] [ text (String.left 120 post.body ++ "...") ]
        ]


httpErrorToString : Http.Error -> String
httpErrorToString error =
    case error of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Bad status: " ++ String.fromInt status

        Http.BadBody body ->
            "Bad body: " ++ body
