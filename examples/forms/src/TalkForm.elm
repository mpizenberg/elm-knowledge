module TalkForm exposing
    ( Accessors
    , Error(..)
    , Form
    , Format(..)
    , Output
    , State
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
    , abstract : Field String
    , format : Field Format
    , duration : Field (Maybe Int)
    , speakers : Forms SpeakerForm.Form
    }


type alias Accessors =
    { title : Accessor State (Field String)
    , abstract : Accessor State (Field String)
    , format : Accessor State (Field Format)
    , duration : Accessor State (Field (Maybe Int))
    , speakers : Accessor State (Forms SpeakerForm.Form)
    , speakerName : Id -> Accessor State (Field String)
    , speakerEmail : Id -> Accessor State (Field String)
    , speakerBio : Id -> Accessor State (Field (Maybe String))
    , addSpeaker : State -> State
    , removeSpeaker : Id -> State -> State
    }


type Error
    = TitleError Field.Error
    | AbstractError Field.Error
    | FormatError Field.Error
    | DurationError Field.Error
    | SpeakerError Id SpeakerForm.Error


type alias Output =
    { title : String
    , abstract : String
    , format : Format
    , duration : Maybe Int
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
    , abstract = Field.empty abstractType
    , format = Field.empty formatType
    , duration = Field.empty durationType
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
    Field.succeed Output
        |> Field.applyValidation (state.title |> Field.mapError TitleError)
        |> Field.applyValidation (state.abstract |> Field.mapError AbstractError)
        |> Field.applyValidation (state.format |> Field.mapError FormatError)
        |> Field.applyValidation (state.duration |> Field.mapError DurationError)
        |> V.apply (Form.List.validate SpeakerError state.speakers)
