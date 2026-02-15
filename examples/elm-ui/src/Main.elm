module Main exposing (main)

import Browser
import Html
import Ui exposing (..)
import Ui.Font as Font
import Ui.Input as Input
import Ui.Responsive as Responsive




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
    { activeTab : Tab
    }


type Tab
    = About
    | Projects


init : () -> ( Model, Cmd Msg )
init _ =
    ( { activeTab = About }
    , Cmd.none
    )



-- UPDATE


type Msg
    = SelectTab Tab


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectTab tab ->
            ( { model | activeTab = tab }, Cmd.none )



-- RESPONSIVE


type Screen
    = Mobile
    | Tablet
    | Desktop


screens : Responsive.Breakpoints Screen
screens =
    Responsive.breakpoints Mobile [ ( 768, Tablet ), ( 1200, Desktop ) ]



-- VIEW


view : Model -> Html.Html Msg
view model =
    Ui.layout (Ui.default |> Ui.withBreakpoints screens) []
        (viewBody model)


viewBody : Model -> Element Msg
viewBody model =
    column
        [ width fill, height fill, padding 40, spacing 32
        , background (rgb 245 245 245)
        , Font.family [ Font.typeface "Inter", Font.sansSerif ]
        ]
        [ viewHeader
        , viewProfileCard model
        , viewFeatureCards
        ]



-- HEADER


viewHeader : Element msg
viewHeader =
    row [ width fill ]
        [ el [ Font.size 24, Font.bold ] (text "elm-ui v2 Demo")
        , -- link is an attribute in v2, not an element
          el
            [ alignRight
            , link "https://github.com/mdgriffith/elm-ui/tree/2.0"
            , Font.color (rgb 0 120 255)
            ]
            (text "View on GitHub")
        ]



-- PROFILE CARD


viewProfileCard : Model -> Element Msg
viewProfileCard model =
    column
        [ width fill, widthMax 600, centerX
        , padding 24, spacing 20
        , background (rgb 255 255 255)
        , rounded 12, border 1, borderColor (rgb 220 220 220)
        ]
        [ viewCardHeader
        , viewTabs model.activeTab
        , viewTabContent model.activeTab
        ]


viewCardHeader : Element msg
viewCardHeader =
    row [ spacing 16, width fill ]
        [ -- Avatar: contentCenterX/Y (new in v2) centers the child
          el
            [ width (px 64), height (px 64), rounded 32
            , background (rgb 0 120 255)
            , Font.color (rgb 255 255 255), Font.size 24, Font.bold
            , contentCenterX, contentCenterY
            ]
            (text "E")
        , column [ spacing 4 ]
            [ el [ Font.size 20, Font.bold ] (text "Elm Developer")
            , el [ Font.size 14, Font.color (rgb 120 120 120) ]
                (text "Building with elm-ui v2")
            ]
        ]


viewTabs : Tab -> Element Msg
viewTabs activeTab =
    row [ spacing 8 ]
        [ viewTab activeTab About "About"
        , viewTab activeTab Projects "Projects"
        ]


viewTab : Tab -> Tab -> String -> Element Msg
viewTab activeTab tab label =
    let
        isActive =
            activeTab == tab
    in
    -- button is an attribute in v2, not an element
    el
        [ Input.button (SelectTab tab)
        , padding 10, rounded 6, Font.size 14
        , attrIf isActive (background (rgb 0 120 255))
        , attrIf isActive (Font.color (rgb 255 255 255))
        , attrIf (not isActive) (background (rgb 240 240 240))
        , attrIf (not isActive) (Font.color (rgb 60 60 60))
        ]
        (text label)


viewTabContent : Tab -> Element msg
viewTabContent tab =
    case tab of
        About ->
            column [ spacing 8 ]
                [ el [ Font.bold ] (text "About")
                , el [ Font.size 14, Font.color (rgb 80 80 80) ]
                    (text "This demo showcases elm-ui v2: layout primitives, the spacing model, attribute composition with attrIf, buttons/links as attributes, and pure CSS responsive design (resize the window to see the feature cards stack on mobile).")
                ]

        Projects ->
            column [ spacing 8 ]
                [ el [ Font.bold ] (text "Projects")
                , viewProjectItem "elm-ui" "Layout and design system for Elm"
                , viewProjectItem "elm-concurrent-task" "Composable task ports"
                , viewProjectItem "elm-markdown" "Customizable markdown parsing"
                ]


viewProjectItem : String -> String -> Element msg
viewProjectItem name description =
    row [ spacing 12, padding 12, width fill, background (rgb 250 250 250), rounded 8 ]
        [ column [ spacing 4 ]
            [ el [ Font.size 14, Font.bold ] (text name)
            , el [ Font.size 12, Font.color (rgb 120 120 120) ] (text description)
            ]
        ]



-- FEATURE CARDS


viewFeatureCards : Element msg
viewFeatureCards =
    -- column on mobile, row on tablet/desktop (pure CSS, no subscriptions)
    Responsive.rowWhen screens [ Tablet, Desktop ] [ spacing 16, width fill ]
        [ viewFeatureCard "Layout" "el, row, column with padding + spacing (no margins)"
        , viewFeatureCard "Styling" "background, border, rounded — all in the Ui module now"
        , viewFeatureCard "Composition" "noAttr, attrs, attrIf for conditional styling"
        ]


viewFeatureCard : String -> String -> Element msg
viewFeatureCard title description =
    column
        [ width (portion 1), padding 20, spacing 8
        , background (rgb 255 255 255), rounded 8
        , border 1, borderColor (rgb 230 230 230)
        ]
        [ el [ Font.size 16, Font.bold ] (text title)
        , el [ Font.size 13, Font.color (rgb 100 100 100) ] (text description)
        ]
