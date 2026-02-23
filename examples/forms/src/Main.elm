module Main exposing (main)

import Browser
import Field exposing (Field)
import Form
import Form.List exposing (Id)
import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Html.Keyed as HK
import Process
import SpeakerForm
import TalkForm
import Task



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( init, Cmd.none )
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }



-- MODEL


type alias Model =
    { talk : TalkForm.Form
    , submitted : Maybe TalkForm.Output
    , existingTitles : List String
    }


init : Model
init =
    { talk = TalkForm.form
    , submitted = Nothing
    , existingTitles =
        [ "Introduction to Elm"
        , "Type-Safe Web Apps"
        , "Functional Reactive Programming"
        ]
    }



-- UPDATE


type Msg
    = InputTitle String
    | TitleCheckResult String
    | InputAbstract String
    | InputFormat String
    | InputDuration String
    | InputMaxParticipants String
    | InputEquipment String
    | InputSpeakerName Id String
    | InputSpeakerEmail Id String
    | InputSpeakerBio Id String
    | AddSpeaker
    | RemoveSpeaker Id
    | Submit


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        InputTitle s ->
            let
                trimmed =
                    String.trim s

                newTalk =
                    model.talk
                        |> Form.modify .title (Field.setFromString s)
                        |> Form.set .titleStatus
                            (if trimmed == "" then
                                TalkForm.NotChecked

                             else
                                TalkForm.Checking
                            )

                cmd =
                    if trimmed == "" then
                        Cmd.none

                    else
                        Process.sleep 2000
                            |> Task.perform (\_ -> TitleCheckResult trimmed)
            in
            ( { model | talk = newTalk }, cmd )

        TitleCheckResult checkedTitle ->
            let
                currentTitle =
                    Form.get .title model.talk
                        |> Field.toRawString
                        |> String.trim
            in
            if checkedTitle == currentTitle then
                let
                    isTaken =
                        List.any
                            (\t -> String.toLower t == String.toLower checkedTitle)
                            model.existingTitles

                    status =
                        if isTaken then
                            TalkForm.Taken

                        else
                            TalkForm.Available
                in
                ( { model | talk = Form.set .titleStatus status model.talk }
                , Cmd.none
                )

            else
                -- Title changed since check was initiated, ignore stale result
                ( model, Cmd.none )

        InputAbstract s ->
            ( { model | talk = Form.modify .abstract (Field.setFromString s) model.talk }
            , Cmd.none
            )

        InputFormat s ->
            ( { model | talk = Form.modify .format (Field.setFromString s) model.talk }
            , Cmd.none
            )

        InputDuration s ->
            ( { model | talk = Form.modify .duration (Field.setFromString s) model.talk }
            , Cmd.none
            )

        InputMaxParticipants s ->
            ( { model | talk = Form.modify .maxParticipants (Field.setFromString s) model.talk }
            , Cmd.none
            )

        InputEquipment s ->
            ( { model | talk = Form.modify .equipment (Field.setFromString s) model.talk }
            , Cmd.none
            )

        InputSpeakerName id s ->
            ( { model | talk = Form.modify (\a -> a.speakerName id) (Field.setFromString s) model.talk }
            , Cmd.none
            )

        InputSpeakerEmail id s ->
            ( { model | talk = Form.modify (\a -> a.speakerEmail id) (Field.setFromString s) model.talk }
            , Cmd.none
            )

        InputSpeakerBio id s ->
            ( { model | talk = Form.modify (\a -> a.speakerBio id) (Field.setFromString s) model.talk }
            , Cmd.none
            )

        AddSpeaker ->
            ( { model | talk = Form.update .addSpeaker model.talk }
            , Cmd.none
            )

        RemoveSpeaker id ->
            ( { model | talk = Form.update (\a -> a.removeSpeaker id) model.talk }
            , Cmd.none
            )

        Submit ->
            ( { model
                | submitted = Form.validateAsMaybe model.talk
                , talk = TalkForm.form
              }
            , Cmd.none
            )



-- VIEW


view : Model -> H.Html Msg
view model =
    H.div []
        [ H.h1 [] [ H.text "Conference Talk Submission" ]
        , H.p [ HA.class "subtitle" ] [ H.text "Submit a talk proposal with one or more speakers." ]
        , H.div [ HA.class "tip" ]
            [ H.text "Try entering the title "
            , H.strong [] [ H.text "\"Introduction to Elm\"" ]
            , H.text " — it will be flagged as already taken after a simulated server check."
            ]
        , viewForm model.talk
        , viewOutput model.submitted
        ]


viewForm : TalkForm.Form -> H.Html Msg
viewForm talk =
    let
        state =
            Form.toState talk

        selectedFormat =
            Form.get .format talk |> Field.toMaybe
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
        , viewTitleStatus (Form.get .titleStatus talk)
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
        , viewFormatFields selectedFormat talk
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


viewTitleStatus : TalkForm.TitleStatus -> H.Html Msg
viewTitleStatus status =
    case status of
        TalkForm.NotChecked ->
            H.text ""

        TalkForm.Checking ->
            H.div [ HA.class "title-status checking" ]
                [ H.text "Checking availability..." ]

        TalkForm.Available ->
            H.div [ HA.class "title-status available" ]
                [ H.text "Title is available" ]

        TalkForm.Taken ->
            H.div [ HA.class "title-status taken" ]
                [ H.text "This title is already taken." ]


viewFormatFields : Maybe TalkForm.Format -> TalkForm.Form -> H.Html Msg
viewFormatFields maybeFormat talk =
    case maybeFormat of
        Just TalkForm.Talk ->
            H.div [ HA.class "format-details" ]
                [ viewTextField
                    { id = "duration"
                    , label = "Duration (minutes)"
                    , required = False
                    , field = Form.get .duration talk
                    , onInput = InputDuration
                    , hint = "Optional override, 1-480 minutes"
                    }
                ]

        Just TalkForm.Lightning ->
            H.text ""

        Just TalkForm.Workshop ->
            H.div [ HA.class "format-details" ]
                [ viewTextField
                    { id = "max-participants"
                    , label = "Max participants"
                    , required = True
                    , field = Form.get .maxParticipants talk
                    , onInput = InputMaxParticipants
                    , hint = "1-500 participants"
                    }
                , viewTextareaField
                    { id = "equipment"
                    , label = "Required equipment"
                    , required = False
                    , field = Form.get .equipment talk
                    , onInput = InputEquipment
                    , hint = "Optional: projector, whiteboard, etc."
                    }
                ]

        Nothing ->
            H.text ""


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
                     , H.dd [] [ H.text (formatOutputLabel output.format) ]
                     ]
                        ++ viewFormatOutputDetails output.format
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


formatOutputLabel : TalkForm.FormatOutput -> String
formatOutputLabel fo =
    case fo of
        TalkForm.TalkOutput _ ->
            "Talk"

        TalkForm.LightningOutput ->
            "Lightning Talk"

        TalkForm.WorkshopOutput _ ->
            "Workshop"


viewFormatOutputDetails : TalkForm.FormatOutput -> List (H.Html Msg)
viewFormatOutputDetails fo =
    case fo of
        TalkForm.TalkOutput (Just d) ->
            [ H.dt [] [ H.text "Duration" ]
            , H.dd [] [ H.text (String.fromInt d ++ " minutes") ]
            ]

        TalkForm.TalkOutput Nothing ->
            []

        TalkForm.LightningOutput ->
            []

        TalkForm.WorkshopOutput details ->
            [ H.dt [] [ H.text "Max participants" ]
            , H.dd [] [ H.text (String.fromInt details.maxParticipants) ]
            ]
                ++ (case details.equipment of
                        Just eq ->
                            [ H.dt [] [ H.text "Required equipment" ]
                            , H.dd [] [ H.text eq ]
                            ]

                        Nothing ->
                            []
                   )
