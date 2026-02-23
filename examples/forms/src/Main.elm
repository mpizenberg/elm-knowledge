module Main exposing (main)

import Browser
import Field exposing (Field)
import Form
import Form.List exposing (Id)
import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Html.Keyed as HK
import SpeakerForm
import TalkForm



-- MAIN


main : Program () Model Msg
main =
    Browser.sandbox
        { init = init
        , update = update
        , view = view
        }



-- MODEL


type alias Model =
    { talk : TalkForm.Form
    , submitted : Maybe TalkForm.Output
    }


init : Model
init =
    { talk = TalkForm.form
    , submitted = Nothing
    }



-- UPDATE


type Msg
    = InputTitle String
    | InputAbstract String
    | InputFormat String
    | InputDuration String
    | InputSpeakerName Id String
    | InputSpeakerEmail Id String
    | InputSpeakerBio Id String
    | AddSpeaker
    | RemoveSpeaker Id
    | Submit


update : Msg -> Model -> Model
update msg model =
    case msg of
        InputTitle s ->
            { model | talk = Form.modify .title (Field.setFromString s) model.talk }

        InputAbstract s ->
            { model | talk = Form.modify .abstract (Field.setFromString s) model.talk }

        InputFormat s ->
            { model | talk = Form.modify .format (Field.setFromString s) model.talk }

        InputDuration s ->
            { model | talk = Form.modify .duration (Field.setFromString s) model.talk }

        InputSpeakerName id s ->
            { model | talk = Form.modify (\a -> a.speakerName id) (Field.setFromString s) model.talk }

        InputSpeakerEmail id s ->
            { model | talk = Form.modify (\a -> a.speakerEmail id) (Field.setFromString s) model.talk }

        InputSpeakerBio id s ->
            { model | talk = Form.modify (\a -> a.speakerBio id) (Field.setFromString s) model.talk }

        AddSpeaker ->
            { model | talk = Form.update .addSpeaker model.talk }

        RemoveSpeaker id ->
            { model | talk = Form.update (\a -> a.removeSpeaker id) model.talk }

        Submit ->
            { model
                | submitted = Form.validateAsMaybe model.talk
                , talk = TalkForm.form
            }



-- VIEW


view : Model -> H.Html Msg
view model =
    H.div []
        [ H.h1 [] [ H.text "Conference Talk Submission" ]
        , H.p [ HA.class "subtitle" ] [ H.text "Submit a talk proposal with one or more speakers." ]
        , viewForm model.talk
        , viewOutput model.submitted
        ]


viewForm : TalkForm.Form -> H.Html Msg
viewForm talk =
    let
        state =
            Form.toState talk
    in
    H.form [ HE.onSubmit Submit, HA.novalidate True ]
        [ viewTextField
            { id = "title"
            , label = "Talk title"
            , required = True
            , field = Form.get .title talk
            , onInput = InputTitle
            , hint = "At least 5 characters"
            }
        , viewTextareaField
            { id = "abstract"
            , label = "Abstract"
            , required = True
            , field = Form.get .abstract talk
            , onInput = InputAbstract
            , hint = "Describe your talk in 20-500 characters"
            }
        , viewSelectField
            { id = "format"
            , label = "Format"
            , required = True
            , field = Form.get .format talk
            , onInput = InputFormat
            , options =
                [ ( "", "-- Select a format --" )
                , ( "talk", "Talk (30 min)" )
                , ( "lightning", "Lightning Talk (5 min)" )
                , ( "workshop", "Workshop (2 hours)" )
                ]
            }
        , viewTextField
            { id = "duration"
            , label = "Duration (minutes)"
            , required = False
            , field = Form.get .duration talk
            , onInput = InputDuration
            , hint = "Optional override, 1-480 minutes"
            }
        , H.h2 [] [ H.text "Speakers" ]
        , viewSpeakers state.speakers
        , H.button
            [ HA.class "add-btn"
            , HA.type_ "button"
            , HE.onClick AddSpeaker
            ]
            [ H.text "+ Add another speaker" ]
        , H.div [ HA.class "field" ]
            [ H.button
                [ HA.type_ "submit"
                , HA.disabled (Form.isInvalid talk)
                ]
                [ H.text "Submit Proposal" ]
            ]
        ]


viewSpeakers : Form.List.Forms SpeakerForm.Form -> H.Html Msg
viewSpeakers speakers =
    HK.node "div"
        []
        (speakers
            |> Form.List.toList
            |> List.indexedMap
                (\index ( id, speaker ) ->
                    ( String.fromInt id
                    , viewSpeaker index id speaker
                    )
                )
        )


viewSpeaker : Int -> Id -> SpeakerForm.Form -> H.Html Msg
viewSpeaker index id speaker =
    H.div [ HA.class "speaker-card" ]
        [ H.button
            [ HA.class "remove-btn"
            , HA.type_ "button"
            , HE.onClick (RemoveSpeaker id)
            ]
            [ H.text "x" ]
        , H.strong [] [ H.text ("Speaker #" ++ String.fromInt (index + 1)) ]
        , viewTextField
            { id = "speaker-name-" ++ String.fromInt id
            , label = "Name"
            , required = True
            , field = Form.get .name speaker
            , onInput = InputSpeakerName id
            , hint = ""
            }
        , viewTextField
            { id = "speaker-email-" ++ String.fromInt id
            , label = "Email"
            , required = True
            , field = Form.get .email speaker
            , onInput = InputSpeakerEmail id
            , hint = ""
            }
        , viewTextareaField
            { id = "speaker-bio-" ++ String.fromInt id
            , label = "Short bio"
            , required = False
            , field = Form.get .bio speaker
            , onInput = InputSpeakerBio id
            , hint = "Optional, max 200 characters"
            }
        ]



-- VIEW HELPERS


viewTextField :
    { id : String
    , label : String
    , required : Bool
    , field : Field a
    , onInput : String -> Msg
    , hint : String
    }
    -> H.Html Msg
viewTextField config =
    let
        showError =
            Field.isDirty config.field && Field.isInvalid config.field

        errorMsg =
            if showError then
                case Field.firstError config.field of
                    Just err ->
                        H.div [ HA.class "error-msg" ] [ H.text (errorToString err) ]

                    Nothing ->
                        H.text ""

            else if config.hint /= "" then
                H.div [ HA.class "hint" ] [ H.text config.hint ]

            else
                H.text ""
    in
    H.div [ HA.class "field" ]
        [ H.label
            [ HA.for config.id
            , if config.required then
                HA.class "required"

              else
                HA.class ""
            ]
            [ H.text config.label ]
        , H.input
            [ HA.type_ "text"
            , HA.id config.id
            , HA.value (Field.toRawString config.field)
            , HE.onInput config.onInput
            , if showError then
                HA.class "error-input"

              else
                HA.class ""
            ]
            []
        , errorMsg
        ]


viewTextareaField :
    { id : String
    , label : String
    , required : Bool
    , field : Field a
    , onInput : String -> Msg
    , hint : String
    }
    -> H.Html Msg
viewTextareaField config =
    let
        showError =
            Field.isDirty config.field && Field.isInvalid config.field

        errorMsg =
            if showError then
                case Field.firstError config.field of
                    Just err ->
                        H.div [ HA.class "error-msg" ] [ H.text (errorToString err) ]

                    Nothing ->
                        H.text ""

            else if config.hint /= "" then
                H.div [ HA.class "hint" ] [ H.text config.hint ]

            else
                H.text ""
    in
    H.div [ HA.class "field" ]
        [ H.label
            [ HA.for config.id
            , if config.required then
                HA.class "required"

              else
                HA.class ""
            ]
            [ H.text config.label ]
        , H.textarea
            [ HA.id config.id
            , HA.value (Field.toRawString config.field)
            , HE.onInput config.onInput
            , if showError then
                HA.class "error-input"

              else
                HA.class ""
            ]
            []
        , errorMsg
        ]


viewSelectField :
    { id : String
    , label : String
    , required : Bool
    , field : Field a
    , onInput : String -> Msg
    , options : List ( String, String )
    }
    -> H.Html Msg
viewSelectField config =
    let
        showError =
            Field.isDirty config.field && Field.isInvalid config.field
    in
    H.div [ HA.class "field" ]
        [ H.label
            [ HA.for config.id
            , if config.required then
                HA.class "required"

              else
                HA.class ""
            ]
            [ H.text config.label ]
        , H.select
            [ HA.id config.id
            , HE.onInput config.onInput
            , if showError then
                HA.class "error-input"

              else
                HA.class ""
            ]
            (List.map
                (\( val, txt ) ->
                    H.option
                        [ HA.value val
                        , HA.selected (Field.toRawString config.field == val)
                        ]
                        [ H.text txt ]
                )
                config.options
            )
        , if showError then
            case Field.firstError config.field of
                Just err ->
                    H.div [ HA.class "error-msg" ] [ H.text (errorToString err) ]

                Nothing ->
                    H.text ""

          else
            H.text ""
        ]


errorToString : Field.Error -> String
errorToString =
    Field.errorToString
        { onBlank = "This field is required."
        , onSyntaxError = \s -> "Invalid value: \"" ++ s ++ "\"."
        , onValidationError = \s -> "Invalid: \"" ++ s ++ "\"."
        }



-- VIEW OUTPUT


viewOutput : Maybe TalkForm.Output -> H.Html Msg
viewOutput maybeOutput =
    case maybeOutput of
        Nothing ->
            H.text ""

        Just output ->
            H.div [ HA.class "output" ]
                [ H.h2 [] [ H.text "Submitted!" ]
                , H.dl []
                    ([ H.dt [] [ H.text "Title" ]
                     , H.dd [] [ H.text output.title ]
                     , H.dt [] [ H.text "Abstract" ]
                     , H.dd [] [ H.text output.abstract ]
                     , H.dt [] [ H.text "Format" ]
                     , H.dd [] [ H.text (TalkForm.formatToString output.format) ]
                     ]
                        ++ (case output.duration of
                                Just d ->
                                    [ H.dt [] [ H.text "Duration" ]
                                    , H.dd [] [ H.text (String.fromInt d ++ " minutes") ]
                                    ]

                                Nothing ->
                                    []
                           )
                        ++ [ H.dt [] [ H.text "Speakers" ]
                           , H.dd []
                                [ H.ul []
                                    (List.map
                                        (\s ->
                                            H.li []
                                                [ H.strong [] [ H.text s.name ]
                                                , H.text (" <" ++ s.email ++ ">")
                                                , case s.bio of
                                                    Just bio ->
                                                        H.text (" - " ++ bio)

                                                    Nothing ->
                                                        H.text ""
                                                ]
                                        )
                                        output.speakers
                                    )
                                ]
                           ]
                    )
                ]
