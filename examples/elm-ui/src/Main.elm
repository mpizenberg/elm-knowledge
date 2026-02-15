module Main exposing (main)

import Browser
import Design
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
    Ui.layout (Ui.default |> Ui.withBreakpoints screens) [] (viewBody model)


viewBody : Model -> Element Msg
viewBody model =
    column
        [ width fill
        , height fill
        , padding Design.space.xxl
        , spacing Design.space.xl
        , background Design.backgroundPage
        , Design.bodyFont
        ]
        [ viewHeader
        , viewProfileCard model
        , viewFeatureCards
        ]



-- HEADER


viewHeader : Element msg
viewHeader =
    row [ width fill ]
        [ el [ Design.heading ] (text "elm-ui v2 Demo")
        , -- link is an attribute in v2, not an element
          el
            [ alignRight
            , link "https://github.com/mdgriffith/elm-ui/tree/2.0"
            , Font.color Design.primary
            ]
            (text "View on GitHub")
        ]



-- PROFILE CARD


viewProfileCard : Model -> Element Msg
viewProfileCard model =
    column
        [ width fill
        , widthMax Design.cardMaxWidth
        , centerX
        , padding Design.space.lg
        , spacing Design.space.md
        , Design.card
        ]
        [ viewCardHeader
        , viewTabs model.activeTab
        , viewTabContent model.activeTab
        ]


viewCardHeader : Element msg
viewCardHeader =
    row [ spacing Design.space.md, width fill ]
        [ -- Avatar: contentCenterX/Y (new in v2) centers the child
          el
            [ width (px Design.avatarSize)
            , height (px Design.avatarSize)
            , rounded (Design.avatarSize // 2)
            , background Design.primary
            , Font.color Design.white
            , Design.heading
            , contentCenterX
            , contentCenterY
            ]
            (text "E")
        , column [ spacing Design.space.xs ]
            [ el [ Design.subheading ] (text "Elm Developer")
            , el [ Design.body, Font.color Design.textMuted ]
                (text "Building with elm-ui v2")
            ]
        ]


viewTabs : Tab -> Element Msg
viewTabs activeTab =
    row [ spacing Design.space.sm ]
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
    -- Design.tag / Design.tagActive bundle the common styles
    el
        [ Input.button (SelectTab tab)
        , attrIf isActive Design.tagActive
        , attrIf (not isActive) Design.tag
        ]
        (text label)


viewTabContent : Tab -> Element msg
viewTabContent tab =
    case tab of
        About ->
            column [ spacing Design.space.sm ]
                [ el [ Font.bold ] (text "About")
                , el [ Design.body, Font.color Design.textMuted ]
                    (text "This demo showcases elm-ui v2: layout primitives, the spacing model, attribute composition with attrIf, buttons/links as attributes, pure CSS responsive design (resize the window to see the feature cards stack on mobile), and a Design module for cohesive styling.")
                ]

        Projects ->
            column [ spacing Design.space.sm ]
                [ el [ Font.bold ] (text "Projects")
                , viewProjectItem "elm-ui" "Layout and design system for Elm"
                , viewProjectItem "elm-concurrent-task" "Composable task ports"
                , viewProjectItem "elm-markdown" "Customizable markdown parsing"
                ]


viewProjectItem : String -> String -> Element msg
viewProjectItem name description =
    row [ spacing Design.space.sm, padding Design.space.sm, width fill, background Design.backgroundMuted, rounded Design.round.sm ]
        [ column [ spacing Design.space.xs ]
            [ el [ Design.label ] (text name)
            , el [ Design.caption, Font.color Design.textMuted ] (text description)
            ]
        ]



-- FEATURE CARDS


viewFeatureCards : Element msg
viewFeatureCards =
    -- column on mobile, row on tablet/desktop (pure CSS, no subscriptions)
    Responsive.rowWhen screens
        [ Tablet, Desktop ]
        [ spacing Design.space.md, width fill ]
        [ viewFeatureCard "Layout" "el, row, column with padding + spacing (no margins)"
        , viewFeatureCard "Styling" "background, border, rounded — all in the Ui module now"
        , viewFeatureCard "Composition" "noAttr, attrs, attrIf for conditional styling"
        , viewFeatureCard "Design Module" "centralized colors, typography, and component styles"
        ]


viewFeatureCard : String -> String -> Element msg
viewFeatureCard title description =
    column
        [ width (portion 1)
        , padding Design.space.md
        , spacing Design.space.sm
        , background Design.backgroundCard
        , rounded Design.round.sm
        , border 1
        , borderColor Design.borderSubtle
        ]
        [ el [ Design.subtitle ] (text title)
        , el [ Design.caption, Font.color Design.textSubtle ] (text description)
        ]
