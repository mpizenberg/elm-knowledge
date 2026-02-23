module SpeakerForm exposing
    ( Accessors
    , Error(..)
    , Form
    , Output
    , State
    , form
    )

import Field exposing (Field, Validation)
import Form exposing (Accessor)



-- FORM


type alias Form =
    Form.Form State Accessors Error Output


type alias State =
    { name : Field String
    , email : Field String
    , bio : Field (Maybe String)
    }


type alias Accessors =
    { name : Accessor State (Field String)
    , email : Accessor State (Field String)
    , bio : Accessor State (Field (Maybe String))
    }


type Error
    = NameError Field.Error
    | EmailError Field.Error
    | BioError Field.Error


type alias Output =
    { name : String
    , email : String
    , bio : Maybe String
    }


form : Form
form =
    Form.new
        { init = init
        , accessors = accessors
        , validate = validate
        }



-- INIT


init : State
init =
    { name = Field.empty Field.nonBlankString
    , email = Field.empty emailType
    , bio = Field.empty (Field.optional bioType)
    }


emailType : Field.Type String
emailType =
    Field.customType
        { fromString =
            Field.trim
                (\s ->
                    if String.contains "@" s && String.contains "." s then
                        Ok s

                    else
                        Err (Field.customError "Must be a valid email address.")
                )
        , toString = identity
        }


bioType : Field.Type String
bioType =
    Field.customType
        { fromString =
            Field.trim
                (\s ->
                    if String.length s > 200 then
                        Err (Field.customError "Bio must be 200 characters or fewer.")

                    else
                        Ok s
                )
        , toString = identity
        }



-- ACCESSORS


accessors : Accessors
accessors =
    { name =
        { get = .name
        , modify = \f state -> { state | name = f state.name }
        }
    , email =
        { get = .email
        , modify = \f state -> { state | email = f state.email }
        }
    , bio =
        { get = .bio
        , modify = \f state -> { state | bio = f state.bio }
        }
    }



-- VALIDATE


validate : State -> Validation Error Output
validate state =
    Field.succeed Output
        |> Field.applyValidation (state.name |> Field.mapError NameError)
        |> Field.applyValidation (state.email |> Field.mapError EmailError)
        |> Field.applyValidation (state.bio |> Field.mapError BioError)
