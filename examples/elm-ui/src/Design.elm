module Design exposing
    ( avatarSize
    , backgroundCard
    , backgroundMuted
    , backgroundPage
    , body
    , bodyFont
    , borderLight
    , borderSubtle
    , caption
    , card
    , cardMaxWidth
    , fontSize
    , heading
    , label
    , primary
    , round
    , space
    , subheading
    , subtitle
    , tag
    , tagActive
    , textDefault
    , textMuted
    , textSubtle
    , white
    )

{-| Centralized design tokens and reusable styles.

Defining colors, typography, and component styles in one module keeps the design
cohesive and makes updates easy — change a color here, it updates everywhere.
Each value is an `Attribute msg` (or `Color`), so they compose naturally with
elm-ui's attribute lists.

-}

import Ui exposing (..)
import Ui.Font as Font



-- SIZING


space : { xs : Int, sm : Int, md : Int, lg : Int, xl : Int, xxl : Int }
space =
    { xs = 4
    , sm = 8
    , md = 16
    , lg = 24
    , xl = 32
    , xxl = 40
    }


fontSize : { xs : Int, sm : Int, md : Int, lg : Int, xl : Int }
fontSize =
    { xs = 12
    , sm = 14
    , md = 16
    , lg = 20
    , xl = 24
    }


round : { sm : Int, lg : Int }
round =
    { sm = 8
    , lg = 12
    }


avatarSize : Int
avatarSize =
    64


cardMaxWidth : Int
cardMaxWidth =
    600



-- COLORS


primary : Color
primary =
    rgb 0 120 255


white : Color
white =
    rgb 255 255 255


textDefault : Color
textDefault =
    rgb 60 60 60


textMuted : Color
textMuted =
    rgb 120 120 120


textSubtle : Color
textSubtle =
    rgb 100 100 100


backgroundPage : Color
backgroundPage =
    rgb 245 245 245


backgroundCard : Color
backgroundCard =
    rgb 255 255 255


backgroundMuted : Color
backgroundMuted =
    rgb 240 240 240


borderLight : Color
borderLight =
    rgb 220 220 220


borderSubtle : Color
borderSubtle =
    rgb 230 230 230



-- TYPOGRAPHY


bodyFont : Attribute msg
bodyFont =
    Font.family [ Font.typeface "Inter", Font.sansSerif ]


heading : Attribute msg
heading =
    attrs [ Font.size fontSize.xl, Font.bold ]


subheading : Attribute msg
subheading =
    attrs [ Font.size fontSize.lg, Font.bold ]


subtitle : Attribute msg
subtitle =
    attrs [ Font.size fontSize.md, Font.bold ]


label : Attribute msg
label =
    attrs [ Font.size fontSize.sm, Font.bold ]


body : Attribute msg
body =
    Font.size fontSize.sm


caption : Attribute msg
caption =
    Font.size fontSize.xs



-- COMPONENTS


card : Attribute msg
card =
    attrs [ background backgroundCard, rounded round.lg, border 1, borderColor borderLight ]


tag : Attribute msg
tag =
    attrs [ padding space.sm, rounded round.sm, body, background backgroundMuted, Font.color textDefault ]


tagActive : Attribute msg
tagActive =
    attrs [ padding space.sm, rounded round.sm, body, background primary, Font.color white ]
