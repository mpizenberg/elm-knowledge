module TalkForm exposing
    ( Accessors
    , Error(..)
    , Form
    , Format(..)
    , FormatOutput(..)
    , Output
    , State
    , TitleStatus(..)
    , form
    , formatToString
    )

import Field exposing (Field, Validation)
import Form exposing (Accessor)
import Form.List exposing (Forms, Id)
import SpeakerForm
import Validation as V



-- FORM


type alias Form =
    Form.Form State Accessors Error Output


type alias State =
    { title : Field String
    , titleStatus : TitleStatus
    , abstract : Field String
    , format : Field Format
    , duration : Field (Maybe Int)
    , maxParticipants : Field Int
    , equipment : Field (Maybe String)
    , speakers : Forms SpeakerForm.Form
    }


type TitleStatus
    = NotChecked
    | Checking
    | Available
    | Taken


type alias Accessors =
    { title : Accessor State (Field String)
    , titleStatus : Accessor State TitleStatus
    , abstract : Accessor State (Field String)
    , format : Accessor State (Field Format)
    , duration : Accessor State (Field (Maybe Int))
    , maxParticipants : Accessor State (Field Int)
    , equipment : Accessor State (Field (Maybe String))
    , speakers : Accessor State (Forms SpeakerForm.Form)
    , speakerName : Id -> Accessor State (Field String)
    , speakerEmail : Id -> Accessor State (Field String)
    , speakerBio : Id -> Accessor State (Field (Maybe String))
    , addSpeaker : State -> State
    , removeSpeaker : Id -> State -> State
    }


type Error
    = TitleError Field.Error
    | TitleTakenError
    | TitleCheckingError
    | AbstractError Field.Error
    | FormatError Field.Error
    | DurationError Field.Error
    | MaxParticipantsError Field.Error
    | EquipmentError Field.Error
    | SpeakerError Id SpeakerForm.Error


type FormatOutput
    = TalkOutput (Maybe Int)
    | LightningOutput
    | WorkshopOutput { maxParticipants : Int, equipment : Maybe String }


type alias Output =
    { title : String
    , abstract : String
    , format : FormatOutput
    , speakers : List SpeakerForm.Output
    }



-- FORMAT


type Format
    = Talk
    | Lightning
    | Workshop


formatFromString : String -> Result Field.Error Format
formatFromString =
    Field.trim
        (\s ->
            case s of
                "talk" ->
                    Ok Talk

                "lightning" ->
                    Ok Lightning

                "workshop" ->
                    Ok Workshop

                _ ->
                    Err (Field.validationError s)
        )


formatToString : Format -> String
formatToString f =
    case f of
        Talk ->
            "talk"

        Lightning ->
            "lightning"

        Workshop ->
            "workshop"


formatType : Field.Type Format
formatType =
    Field.customType
        { fromString = formatFromString
        , toString = formatToString
        }



-- FIELD TYPES


titleType : Field.Type String
titleType =
    Field.customType
        { fromString =
            Field.trim
                (\s ->
                    if String.length s < 5 then
                        Err (Field.customError "Title must be at least 5 characters.")

                    else
                        Ok s
                )
        , toString = identity
        }


abstractType : Field.Type String
abstractType =
    Field.customType
        { fromString =
            Field.trim
                (\s ->
                    let
                        len =
                            String.length s
                    in
                    if len < 20 then
                        Err (Field.customError "Abstract must be at least 20 characters.")

                    else if len > 500 then
                        Err (Field.customError "Abstract must be 500 characters or fewer.")

                    else
                        Ok s
                )
        , toString = identity
        }


durationType : Field.Type (Maybe Int)
durationType =
    Field.optional
        (Field.subsetOfInt (\n -> n >= 1 && n <= 480))


maxParticipantsType : Field.Type Int
maxParticipantsType =
    Field.subsetOfInt (\n -> n >= 1 && n <= 500)



-- INIT / FORM


form : Form
form =
    Form.new
        { init = init
        , accessors = accessors
        , validate = validate
        }


init : State
init =
    { title = Field.empty titleType
    , titleStatus = NotChecked
    , abstract = Field.empty abstractType
    , format = Field.empty formatType
    , duration = Field.empty durationType
    , maxParticipants = Field.empty maxParticipantsType
    , equipment = Field.empty (Field.optional Field.nonBlankString)
    , speakers = Form.List.fromList [ SpeakerForm.form ]
    }



-- ACCESSORS


emptyName : Field String
emptyName =
    Field.empty Field.nonBlankString


emptyEmail : Field String
emptyEmail =
    Field.empty Field.nonBlankString


emptyBio : Field (Maybe String)
emptyBio =
    Field.empty (Field.optional Field.nonBlankString)


accessors : Accessors
accessors =
    { title =
        { get = .title
        , modify = \f state -> { state | title = f state.title }
        }
    , titleStatus =
        { get = .titleStatus
        , modify = \f state -> { state | titleStatus = f state.titleStatus }
        }
    , abstract =
        { get = .abstract
        , modify = \f state -> { state | abstract = f state.abstract }
        }
    , format =
        { get = .format
        , modify = \f state -> { state | format = f state.format }
        }
    , duration =
        { get = .duration
        , modify = \f state -> { state | duration = f state.duration }
        }
    , maxParticipants =
        { get = .maxParticipants
        , modify = \f state -> { state | maxParticipants = f state.maxParticipants }
        }
    , equipment =
        { get = .equipment
        , modify = \f state -> { state | equipment = f state.equipment }
        }
    , speakers =
        { get = .speakers
        , modify = \f state -> { state | speakers = f state.speakers }
        }
    , speakerName =
        \id ->
            { get = .speakers >> Form.List.get id .name >> Maybe.withDefault emptyName
            , modify = \f state -> { state | speakers = Form.List.modify id .name f state.speakers }
            }
    , speakerEmail =
        \id ->
            { get = .speakers >> Form.List.get id .email >> Maybe.withDefault emptyEmail
            , modify = \f state -> { state | speakers = Form.List.modify id .email f state.speakers }
            }
    , speakerBio =
        \id ->
            { get = .speakers >> Form.List.get id .bio >> Maybe.withDefault emptyBio
            , modify = \f state -> { state | speakers = Form.List.modify id .bio f state.speakers }
            }
    , addSpeaker =
        \state -> { state | speakers = Form.List.append SpeakerForm.form state.speakers }
    , removeSpeaker =
        \id state -> { state | speakers = Form.List.remove id state.speakers }
    }



-- VALIDATE


validate : State -> Validation Error Output
validate state =
    let
        validateTitle =
            Field.validate identity (Field.mapError TitleError state.title)
                |> V.andThen
                    (\title ->
                        case state.titleStatus of
                            Taken ->
                                V.fail TitleTakenError

                            Checking ->
                                V.fail TitleCheckingError

                            _ ->
                                V.succeed title
                    )

        validateFormat =
            Field.validate identity (Field.mapError FormatError state.format)
                |> V.andThen
                    (\format ->
                        case format of
                            Talk ->
                                Field.validate TalkOutput
                                    (Field.mapError DurationError state.duration)

                            Lightning ->
                                V.succeed LightningOutput

                            Workshop ->
                                Field.succeed
                                    (\mp eq ->
                                        WorkshopOutput
                                            { maxParticipants = mp
                                            , equipment = eq
                                            }
                                    )
                                    |> Field.applyValidation
                                        (Field.mapError MaxParticipantsError state.maxParticipants)
                                    |> Field.applyValidation
                                        (Field.mapError EquipmentError state.equipment)
                    )
    in
    V.map4
        Output
        validateTitle
        (Field.validate identity (Field.mapError AbstractError state.abstract))
        validateFormat
        (Form.List.validate SpeakerError state.speakers)
