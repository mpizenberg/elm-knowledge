# Form Handling with dwayne/elm-form

A conference talk submission form demonstrating `dwayne/elm-form` with
`dwayne/elm-field` and `dwayne/elm-validation`.

## What this example covers

- **Custom field types** with validation (`titleType`, `abstractType`, `formatType`, `emailType`)
- **Optional fields** (`duration`, `bio`) using `Field.optional`
- **Dynamic form lists** (`Form.List`) for adding/removing speakers
- **Composable sub-forms** (`SpeakerForm` nested inside `TalkForm`)
- **Error accumulation** via `Validation` (all errors shown at once)
- **Dirty-based error display** (errors only appear after the user interacts with a field)
- **Error-to-string mapping** with `Field.errorToString`
- **Conditional/branching fields** depending on the selected format (`V.andThen`)
- **Simulated remote validation** for title uniqueness (delayed `Task` + non-`Field` state in the form)

## How it works

### Defining a form

Each form module follows a 4-step pattern:

1. **State** -- a record of `Field` values (the raw user input)
2. **Accessors** -- `{ get, modify }` pairs for each field
3. **Error type** -- a union wrapping per-field errors
4. **Validation** -- an applicative pipeline producing a typed `Output`

```elm
-- TalkForm.elm (simplified)
type alias State =
    { title : Field String
    , abstract : Field String
    , format : Field Format
    , speakers : Forms SpeakerForm.Form
    }

validate state =
    Field.succeed Output
        |> Field.applyValidation (state.title |> Field.mapError TitleError)
        |> Field.applyValidation (state.abstract |> Field.mapError AbstractError)
        |> Field.applyValidation (state.format |> Field.mapError FormatError)
        |> V.apply (Form.List.validate SpeakerError state.speakers)
```

### Custom field types

Define parsing and validation in one step with `Field.customType`:

```elm
titleType : Field.Type String
titleType =
    Field.customType
        { fromString =
            Field.trim (\s ->
                if String.length s < 5 then
                    Err (Field.customError "Title must be at least 5 characters.")
                else
                    Ok s
            )
        , toString = identity
        }
```

### Dynamic speaker list

`Form.List` manages an ordered collection of sub-forms with auto-incrementing IDs:

```elm
-- Add a speaker
Form.update .addSpeaker model.talk

-- Remove a speaker by ID
Form.update (\a -> a.removeSpeaker id) model.talk

-- Modify a speaker's field
Form.modify (\a -> a.speakerName id) (Field.setFromString s) model.talk
```

### Conditional fields by format

`V.andThen` enables branching: the format field is validated first, then different
fields are validated depending on the result. Workshop requires extra fields
(max participants, equipment) that Talk and Lightning don't:

```elm
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
                        Field.succeed (\mp eq -> WorkshopOutput { ... })
                            |> Field.applyValidation (Field.mapError MaxParticipantsError state.maxParticipants)
                            |> Field.applyValidation (Field.mapError EquipmentError state.equipment)
            )
```

The view conditionally renders format-specific fields based on `Field.toMaybe`
on the format field.

### Simulated remote validation

Title uniqueness is checked via a simulated server request (`Process.sleep 2000`).
A `TitleStatus` value (not a `Field`) is stored in the form state with its own
accessor, so the validation function can read it:

```elm
type TitleStatus = NotChecked | Checking | Available | Taken

-- In the form state, alongside Field values:
{ title : Field String
, titleStatus : TitleStatus
, ...
}

-- In the validation function, after field-level validation passes:
validateTitle =
    Field.validate identity (Field.mapError TitleError state.title)
        |> V.andThen
            (\title ->
                case state.titleStatus of
                    Taken -> V.fail TitleTakenError
                    Checking -> V.fail TitleCheckingError
                    _ -> V.succeed title
            )
```

On each title keystroke, the status is set to `Checking` and a delayed task is
fired. When it completes, the title is compared against a hardcoded list.
Stale results (title changed since the check started) are discarded.

### Dirty-based error display

Errors are only shown after the user has modified a field:

```elm
showError = Field.isDirty field && Field.isInvalid field
```

## Key patterns

- `Field.empty fieldType` -- create an empty field with a given type
- `Field.setFromString s field` -- update a field from user input (marks it dirty)
- `Field.toRawString field` -- get the raw string for the input's `value` attribute
- `Field.isDirty field` -- has the user modified this field?
- `Field.isInvalid field` -- does this field have validation errors?
- `Field.firstError field` -- get the first error (if any)
- `Field.mapError Tag field` -- wrap a field's errors in a union tag
- `Field.optional fieldType` -- make a field type accept blank as `Nothing`
- `Form.get .accessor form` -- read a field from a form
- `Form.modify .accessor f form` -- apply a function to a field in a form
- `Form.update .action form` -- run a state transformation (e.g. addSpeaker)
- `Form.isInvalid form` -- check if the form has any validation errors
- `Form.validateAsMaybe form` -- extract the validated output or Nothing
- `Form.List.append subForm forms` -- add a sub-form to the list
- `Form.List.remove id forms` -- remove a sub-form by ID
- `Form.List.validate ErrorTag forms` -- validate all sub-forms, tagging errors with their ID
- `Form.set .accessor value form` -- set a non-Field value (e.g. `TitleStatus`) in the form state
- `Field.validate f field` -- convert a field to a `Validation` (useful before `V.andThen`)
- `V.andThen f validation` -- chain validations for conditional/branching logic
- `V.map4 f v1 v2 v3 v4` -- combine 4 independent validations with error accumulation

## Running the example

```sh
elm make src/Main.elm --output=static/elm.js
cd static
python -m http.server 8000
```

## Project structure

```
forms/
├── elm.json
├── README.md
├── src/
│   ├── Main.elm           -- TEA app, view helpers, error display
│   ├── TalkForm.elm       -- Parent form: title (with remote check), format branching, speakers
│   └── SpeakerForm.elm    -- Sub-form: name, email, bio
└── static/
    └── index.html
```
