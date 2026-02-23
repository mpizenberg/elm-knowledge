# Forms in Elm: dwayne/elm-form and Alternatives

## Overview

Form handling in Elm involves managing field state, validation, error display, and TEA integration.
The main challenge is balancing type safety, composability, and boilerplate.
This report analyzes `dwayne/elm-form` (the recommended package) and compares it with alternatives.

---

## dwayne/elm-form

**Repository:** https://github.com/dwayne/elm-form
**Version:** 1.0.0 | **License:** BSD-3-Clause | **Elm:** 0.19.x
**Exposed modules:** `Form`, `Form.List`
**Runtime dependency:** `dwayne/elm-validation` (error-accumulating applicative)
**Companion package:** `dwayne/elm-field` (typed fields with parsing, trimming, dirty tracking)

### Core Architecture

The library is very small (~200 lines) and deliberately provides **no view helpers**.
Form logic (state, accessors, validation) is fully decoupled from UI rendering,
so it works with elm-ui, elm-css, plain HTML, or any other UI framework.

#### The Form Type

```elm
type Form state accessors error output
```

- **`state`** — a record holding the form's fields (typically `Field` values from `dwayne/elm-field`)
- **`accessors`** — a record of getter/modifier pairs for each field, plus custom state transformations
- **`error`** — a custom union type representing all possible validation errors
- **`output`** — the validated, typed result produced by a valid form

#### The Accessor Pattern

Each field bundles a `get` and `modify` function:

```elm
type alias Accessor state a =
    { get : state -> a
    , modify : (a -> a) -> state -> state
    }
```

Accessors can encode **cross-field side effects** — e.g. the password accessor
can automatically re-validate password confirmation when the password changes:

```elm
password =
    { get = .password
    , modify = \f state ->
        let pw = f state.password
        in { state | password = pw
                   , passwordConfirmation = updatePasswordConfirmation pw state.passwordConfirmation }
    }
```

#### Key Functions

| Function | Signature | Purpose |
|---|---|---|
| `new` | `{ init, accessors, validate } -> Form ...` | Construct a form |
| `get` | `(accessors -> Accessor state a) -> Form ... -> a` | Read a field value |
| `set` | `(accessors -> Accessor state a) -> a -> Form ... -> Form ...` | Set a field value |
| `modify` | `(accessors -> Accessor state a) -> (a -> a) -> Form ... -> Form ...` | Transform a field |
| `update` | `(accessors -> state -> state) -> Form ... -> Form ...` | Arbitrary state change |
| `isValid` / `isInvalid` | `Form ... -> Bool` | Quick validity check |
| `validate` | `Form ... -> Validation error output` | Full validation |
| `validateAsMaybe` | `Form ... -> Maybe output` | Validation as Maybe |
| `validateAsResult` | `Form ... -> Result (List error) output` | Validation as Result |
| `toState` | `Form ... -> state` | Extract raw state |

#### Form.List Module

Manages ordered collections of uniquely identifiable sub-forms (e.g. list of people in a group):

```elm
type Forms form   -- internally List (Id, form) with auto-incrementing Id
type alias Id = Int
```

Key functions: `empty`, `fromList`, `get`, `set`, `modify`, `update`,
`prepend`, `append`, `remove`, `validate`, `validateAsMaybe`, `validateAsResult`, `toList`.

### Defining a Form

Four-step pattern:

**1. State (fields):**

```elm
type alias State =
    { firstName : Field String
    , lastName : Field (Maybe String)
    }
```

**2. Accessors:**

```elm
type alias Accessors =
    { firstName : Accessor State (Field String)
    , lastName : Accessor State (Field (Maybe String))
    }

accessors : Accessors
accessors =
    { firstName =
        { get = .firstName
        , modify = \f state -> { state | firstName = f state.firstName }
        }
    , lastName =
        { get = .lastName
        , modify = \f state -> { state | lastName = f state.lastName }
        }
    }
```

**3. Errors and output:**

```elm
type Error
    = FirstNameError Field.Error
    | LastNameError Field.Error

type alias Output = String
```

**4. Validation (applicative style, error-accumulating):**

```elm
validate : State -> Validation Error Output
validate state =
    (\firstName maybeLastName ->
        case maybeLastName of
            Just lastName -> firstName ++ " " ++ lastName
            Nothing -> firstName
    )
        |> Field.succeed
        |> Field.applyValidation (state.firstName |> Field.mapError FirstNameError)
        |> Field.applyValidation (state.lastName |> Field.mapError LastNameError)
```

**Wire it together:**

```elm
form : Form State Accessors Error Output
form =
    Form.new { init = init, accessors = accessors, validate = validate }
```

### TEA Integration

```elm
-- Model
type alias Model =
    { signUp : SignUp.Form
    , maybeOutput : Maybe SignUp.Output
    }

-- Msg: one message per field interaction
type Msg
    = InputUsername String
    | InputEmail String
    | Submit

-- Update: use Form.modify with accessor selectors
update msg model =
    case msg of
        InputUsername s ->
            ( { model | signUp = Form.modify .username (Field.setFromString s) model.signUp }
            , Cmd.none
            )
        Submit ->
            ( { model | maybeOutput = Form.validateAsMaybe model.signUp }
            , Cmd.none
            )

-- View: use Form.get to extract field values
view { signUp } =
    H.form [ HE.onSubmit Submit ]
        [ someInputView
            { field = Form.get .username signUp
            , onInput = InputUsername
            }
        , H.button [ HA.disabled (Form.isInvalid signUp) ] [ H.text "Submit" ]
        ]
```

### Dynamic / Conditional Forms

`V.andThen` enables forms whose structure changes based on user selection:

```elm
validate state =
    state.publication
        |> Field.validate identity
        |> V.andThen
            (\publication ->
                case publication of
                    Publication.Post ->
                        Form.validate state.post |> V.map PostOutput
                    Publication.Question ->
                        Form.validate state.question |> V.map QuestionOutput
            )
```

### Composable Sub-Forms

Forms can nest. A `Group.Form` contains `Forms Person.Form` (a list of person sub-forms).
Validation composes via `V.apply` and `Form.List.validate`.
Error types compose via wrapper constructors like `PersonError Id Person.Error`.

### Strengths

- **Very small surface area.** Two modules, ~200 lines. Easy to understand completely.
- **UI-agnostic.** Works with elm-ui, elm-css, plain HTML, Bulma, anything.
- **Error accumulation by default.** Uses `Validation` (not `Result`), so all errors are collected at once.
- **Composable and nestable.** Sub-forms and dynamic form lists are first-class via `Form.List`.
- **Cross-field validation.** The accessor `modify` hook handles dependent fields elegantly.
- **Testable.** Forms can be constructed, modified, and validated purely without any view code.

### Limitations

- **Accessor boilerplate.** Every field requires a manual `{ get, modify }` record. Tedious for large forms.
- **No built-in view helpers.** Every project must build its own input components and error display.
- **`dwayne/elm-field` practically required.** Although technically optional, the examples and validation patterns are all built around it.
- **No async validation.** Server-side checks (e.g. username uniqueness) are not addressed.
- **No form-level "submitted" tracking.** Display of errors after first submit must be handled in user code.
  (`dwayne/elm-field` tracks per-field "dirty" state via `isDirty`.)

---

## Alternatives

### hecrj/composable-form

**Repository:** https://github.com/hecrj/composable-form
**Version:** 8.0.1 | **Last commit:** November 2019

Uses an applicative builder pattern (`succeed` + `append`) where each field is a self-contained config:

```elm
form =
    Form.succeed Output
        |> Form.append emailField
        |> Form.append passwordField

emailField =
    Form.emailField
        { parser = EmailAddress.parse >> Result.mapError (\_ -> "Invalid email")
        , value = .email
        , update = \value values -> { values | email = value }
        , error = always Nothing
        , attributes = { label = "Email", placeholder = "you@example.com" }
        }
```

TEA integration uses a single `onChange` callback that replaces the entire form model.
The library bundles `Form.View.asHtml` for rendering, with built-in form lifecycle states
(Idle / Loading / Error / Success) and validation strategy choice (on submit vs. on blur).

**Strengths:** Truly composable, minimal boilerplate (no per-field Msg variants),
clean `Form` vs `Form.View` separation, optional fields via `Form.optional`.

**Limitations:** View renders with specific CSS classes (`elm-form-*`).
No elm-ui support. Custom field types require implementing `Form.Base`.

### etaque/elm-form

**Repository:** https://github.com/etaque/elm-form
**Version:** 4.0.0 | **Last commit:** May 2024 (archived, read-only)

Uses a dictionary-based approach with **string field paths**, inspired by `Json.Decode`:

```elm
validate =
    succeed Person
        |> andMap (field "name" (string |> andThen nonEmpty))
        |> andMap (field "address" validateAddress)

-- View: query fields by string path
emailState = Form.getFieldAsString "email" model.form
```

Nested fields use dot-notation (`"address.street"`), dynamic lists use indexed paths (`"items.0.name"`).
The library manages its own `Form.Msg` type and provides pre-wired view helpers
(`textInput`, `passwordInput`, `selectInput`, etc.).

**Strengths:** Familiar `Json.Decode`-like API, dynamic forms are natural with string addressing,
nested and list fields work out of the box, pre-built input helpers.

**Limitations:** **Not type-safe at the field level** — string paths mean typos aren't caught by the compiler.
No form lifecycle state management.

### dillonkearns/elm-form

**Repository:** https://github.com/dillonkearns/elm-form
**Version:** 3.0.1 | **Last commit:** October 2025

Originally extracted from `elm-pages`. Combines validation (`combine`) and rendering (`view`)
in a single definition, ensuring every validated field is also rendered:

```elm
signUpForm =
    (\username password ->
        { combine =
            Validation.succeed SignUpForm
                |> Validation.andMap username
                |> Validation.andMap password
        , view =
            \formState ->
                [ FieldView.input [] username
                , FieldView.input [] password
                , Html.button [] [ Html.text "Sign Up" ]
                ]
        }
    )
    |> Form.form
    |> Form.field "username" (Field.text |> Field.required "Required")
    |> Form.field "password" (Field.text |> Field.password |> Field.required "Required")
```

Supports progressive enhancement (forms work without JS when used with `elm-pages`),
server-side validation error replay via `Form.withServerResponse`,
and both `elm/html` and `elm-css` rendering.

**Strengths:** Combined `combine`/`view` prevents phantom fields.
Type-safe field references (lambda arguments, not strings). Progressive enhancement and accessibility.
Server-side validation support.

**Limitations:** Combined pattern means you can't reuse validation without the view or vice versa.
No elm-ui support (by design — elm-ui doesn't render semantic form elements).
Lambda-based field binding gets unwieldy with many fields.
Originated from `elm-pages`, so some patterns assume that framework.

### choonkeat/formdata

**Repository:** https://github.com/choonkeat/formdata
**Version:** 2.1.0 | **License:** MIT | **Elm:** 0.19.1
**Last commit:** October 2021 | **Stars:** 2
**Exposed module:** `FormData`
**Runtime dependency:** `turboMaCk/any-dict`
**Live demo:** https://elm-formdata.netlify.app

Uses a dictionary-based approach with **custom union type keys** (not strings) and a
"parse, don't validate" philosophy. The entire form state is held in a single opaque
`FormData k a` wrapper backed by `AnyDict`, requiring a `k -> String` conversion function
for key comparability.

#### Core Types

```elm
-- Opaque form state: k = field key type, a = parsed output type
type FormData k a

-- Result of parsing
type Data a
    = Invalid
    | Valid a
    | Submitting a

-- Error container: field-specific errors + global errors (Maybe k = Nothing for global)
type Errors k err
```

#### Full API

| Function | Signature | Purpose |
|---|---|---|
| `init` | `(k -> String) -> List ( k, String ) -> FormData k a` | Create form with key-to-string fn and optional initial values |
| `onInput` | `k -> String -> FormData k a -> FormData k a` | Store text input for a field |
| `value` | `k -> FormData k a -> String` | Read current text value of a field |
| `onCheck` | `k -> Bool -> FormData k a -> FormData k a` | Toggle checkbox (inserts/removes key) |
| `isChecked` | `k -> FormData k a -> Bool` | Check if a checkbox key is present |
| `parse` | `(List ( k, String ) -> ( Maybe a, List ( Maybe k, err ) )) -> FormData k a -> ( Data a, Errors k err )` | Run parser on form data, returning `Data` + errors |
| `onVisited` | `Maybe k -> FormData k a -> FormData k a` | Mark a field (or global) as visited |
| `hadVisited` | `Maybe k -> FormData k a -> Bool` | Check if field was visited |
| `visitedErrors` | `FormData k a -> Errors k err -> Errors k err` | Filter errors to only visited fields |
| `onSubmit` | `Bool -> FormData k a -> FormData k a` | Toggle submission state |
| `isSubmitting` | `FormData k a -> Bool` | Check submission state |
| `errorsFrom` | `(k -> String) -> List ( Maybe k, err ) -> Errors k err` | Construct errors from a list |
| `errorAt` | `Maybe k -> Errors k err -> Maybe err` | Look up error for a specific field (or global with Nothing) |
| `keyValues` | `FormData k a -> List ( k, String )` | Export all form data as key-value pairs |

#### Defining a Form

**1. Define field keys as a union type:**

```elm
type FormField
    = Name
    | Age
    | Location
    | Hobbies Hobby

type Hobby = Soccer | Basketball | Crochet
```

**2. Provide a key-to-string function:**

```elm
stringFormField : FormField -> String
stringFormField f =
    case f of
        Name -> "name"
        Age -> "age"
        Location -> "location"
        Hobbies h -> "hobbies " ++ stringHobby h
```

**3. Write a `parseDontValidate` function:**

This is the central concept. A single function takes `List ( k, String )` and returns
`( Maybe a, List ( Maybe k, err ) )` -- either a parsed value or a list of errors.
Errors keyed with `Just field` attach to that field; `Nothing` denotes global errors.

```elm
parseDontValidate : List ( FormField, String ) -> ( Maybe User, List ( Maybe FormField, String ) )
parseDontValidate keyValueList =
    let
        initial =
            ( { name = "", age = 0, location = "", hobbies = [] }
            , [ ( Just Name, "cannot be blank" )
              , ( Nothing, "must choose one hobby" )
              ]
            )

        fold ( k, s ) ( partUser, partErrs ) =
            case k of
                Name ->
                    ( { partUser | name = s }
                    , if s /= "" then
                        List.filter (\( mk, _ ) -> mk /= Just k) partErrs
                      else
                        partErrs
                    )
                Age ->
                    case String.toInt s of
                        Just i ->
                            ( { partUser | age = i }
                            , if i > 0 then
                                List.filter (\( mk, _ ) -> mk /= Just k) partErrs
                              else
                                ( Just k, "must be a positive number" ) :: partErrs
                            )
                        Nothing ->
                            ( partUser, ( Just k, "is not a number" ) :: partErrs )
                -- ... other fields ...

        ( value, errs ) =
            List.foldl fold initial keyValueList
    in
    if errs == [] then
        ( Just value, [] )
    else
        ( Nothing, errs )
```

#### TEA Integration

The library requires only 2-4 Msg variants regardless of how many fields the form has:

```elm
type alias Model =
    { userForm : FormData FormField User }

type Msg
    = OnInput FormField String
    | OnBlur (Maybe FormField)
    | OnCheck FormField Bool
    | Save User
    | Saved

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnInput k string ->
            ( { model | userForm = FormData.onInput k string model.userForm }, Cmd.none )
        OnBlur k ->
            ( { model | userForm = FormData.onVisited k model.userForm }, Cmd.none )
        OnCheck k bool ->
            ( { model | userForm = FormData.onCheck k bool model.userForm }, Cmd.none )
        Save user ->
            ( { model | userForm = FormData.onSubmit True model.userForm }
            , Process.sleep 1500 |> Task.perform (always Saved)
            )
        Saved ->
            ( { model | userForm = FormData.onSubmit False model.userForm }, Cmd.none )
```

In the view, `FormData.parse` is called to get the current `Data` state and errors,
then `visitedErrors` filters to only show errors for fields the user has interacted with:

```elm
view model =
    let
        ( dataUser, errors ) =
            FormData.parse parseDontValidate model.userForm
                |> Tuple.mapSecond (FormData.visitedErrors model.userForm)
    in
    case dataUser of
        FormData.Invalid -> -- disable submit
        FormData.Valid user -> -- enable submit with (Save user)
        FormData.Submitting user -> -- show loading state
```

#### Notable Design Decisions

- **Union-type keys instead of strings:** Field identifiers are a custom type, giving
  compiler-checked exhaustiveness. Checkbox fields like `Hobbies Soccer` encode the
  value in the key itself (presence/absence in the dict = checked/unchecked).
- **Parse, don't validate:** Inspired by the Haskell blog post of the same name.
  Validation and construction happen in one step -- if parsing succeeds, you have a
  valid value by construction.
- **Visited-field tracking:** Errors are only shown for fields the user has interacted
  with (via `onBlur`), giving good UX without form-level "submitted" state.
- **Submission state built in:** `Data a` has an explicit `Submitting a` variant,
  so the form can disable itself during async operations.
- **Minimal Msg footprint:** Only 2-4 messages total (OnInput, OnBlur, OnCheck, Submit)
  regardless of field count, because the field key is passed as a parameter.

**Strengths:**
- Very small API surface (single module, ~15 functions).
- Type-safe field keys via custom union types with exhaustiveness checking.
- Minimal boilerplate: few Msg variants, no per-field accessor records.
- Built-in visited-field tracking and submission state.
- UI-agnostic: no view helpers, works with any rendering approach.
- Checkbox handling via key presence/absence is elegant for multi-select groups.

**Limitations:**
- **No composability/nesting:** No mechanism for sub-forms or dynamic form lists.
- **Manual `parseDontValidate` function:** The fold-based parsing pattern is verbose
  and error-prone for large forms. Every field must be handled in a single function.
- **No error accumulation guarantees:** The parser returns a flat list -- accumulating
  all errors depends entirely on the user's implementation of the parse function.
- **No built-in field types or validation combinators:** No helpers for common patterns
  like required fields, email validation, number ranges, etc.
- **`turboMaCk/any-dict` dependency:** Adds a non-trivial dependency for the dict wrapper.
- **Key-to-string function is a manual mapping:** Must be kept in sync with the union type;
  the compiler does not enforce exhaustiveness of `k -> String` unless you use a `case`.

### cekrem/elm-form

**Repository:** https://github.com/cekrem/elm-form
**Version:** 1.1.1 | **License:** BSD-3-Clause | **Elm:** 0.19.x
**Created:** December 2025 | **Last activity:** December 2025
**Stars:** 3 | **Status:** Self-described "wip!"
**Exposed modules:** `Form`, `Input`
**Runtime dependencies:** `elm/core`, `elm/html` only

A minimalist form library that stores all field values in a `Dict String String`
and uses **phantom types** to enforce compile-time safety on input rendering.

#### Core Types

The `Input` module uses two phantom types to ensure inputs cannot be rendered
without an interaction handler:

```elm
type Input interaction msg

-- Phantom types (uninhabitable):
type Dumb = Dumb Never           -- no interaction handler yet
type WithInteraction = WithInteraction Never  -- has handler, can be rendered
```

`withOnChange` is the only way to transition from `Dumb` to `WithInteraction`:

```elm
withOnChange : (String -> msg) -> Input Dumb msg -> Input WithInteraction msg
build : String -> Input WithInteraction msg -> Html msg  -- only WithInteraction can render
```

The `Form` module provides a higher-level API that manages `Dict String String` state
and wires interaction handlers automatically via `build`:

```elm
type Form msg          -- opaque: attributes + list of FormInput + optional submit button
type alias FormInput msg = { key : String, input_ : Input Dumb msg }
```

#### Full API

**Form module:**

| Function | Signature | Purpose |
|---|---|---|
| `new` | `List (Attribute msg) -> List (FormInput msg) -> Form msg` | Create a form with HTML attributes and inputs |
| `input` | `String -> String -> FormInput msg` | Create a field with key and label |
| `withRequired` | `Bool -> FormInput msg -> FormInput msg` | Mark as required |
| `withType` | `String -> FormInput msg -> FormInput msg` | Set input type ("email", "password", etc.) |
| `withPlaceholder` | `String -> FormInput msg -> FormInput msg` | Set placeholder text |
| `withTransformer` | `(String -> String) -> FormInput msg -> FormInput msg` | Transform value at input time (e.g. `String.trim`) |
| `withValidator` | `(String -> Result (List (Attribute msg)) ()) -> FormInput msg -> FormInput msg` | Attach validator |
| `withAttributes` | `List (Attribute msg) -> FormInput msg -> FormInput msg` | Add custom HTML attributes |
| `withSubmitButton` | `String -> List (Attribute msg) -> Form msg -> Form msg` | Attach submit button |
| `build` | `Dict String String -> (Dict String String -> msg) -> msg -> Form msg -> Html msg` | Render the form |

**Input module** mirrors most `Form.with*` functions but operates on `Input any msg`,
plus adds `withOnChange`, `withDisabled`, and `build`.

#### Defining a Form

```elm
myForm : Form Msg
myForm =
    Form.new [ Attr.class "my-form" ]
        [ Form.input "name" "Full Name"
            |> Form.withRequired True
            |> Form.withTransformer String.trim
        , Form.input "email" "Email Address"
            |> Form.withType "email"
            |> Form.withRequired True
            |> Form.withValidator emailValidator
        , Form.input "password" "Password"
            |> Form.withType "password"
            |> Form.withRequired True
        ]
        |> Form.withSubmitButton "Submit" []
```

#### Validation Approach

Validators return **HTML attributes on failure** rather than error messages:

```elm
emailValidator : String -> Result (List (Html.Attribute msg)) ()
emailValidator value =
    if String.contains "@" value then
        Ok ()
    else
        Err [ Attr.class "error", Attr.attribute "aria-invalid" "true" ]
```

This pushes error display to CSS/ARIA rather than requiring the library to render
error text. Only one validator per field (last `withValidator` wins).

#### TEA Integration

```elm
type alias Model = { formValues : Dict String String }

type Msg
    = FormChanged (Dict String String)  -- receives the ENTIRE updated dict
    | FormSubmitted

update msg model =
    case msg of
        FormChanged newValues -> ( { model | formValues = newValues }, Cmd.none )
        FormSubmitted -> -- handle submission

view model =
    myForm |> Form.build model.formValues FormChanged FormSubmitted
```

Every keystroke creates a new `Dict` and sends it as the message payload.

#### Notable Design Decisions

- **Phantom types for compile-time safety:** `Dumb`/`WithInteraction` makes it a
  compile error to render an input without an interaction handler. The `Form` module
  handles this automatically, so users of the high-level API never encounter the constraint.
- **Validators return HTML attributes, not error messages:** Error feedback is via
  CSS classes and ARIA attributes only. No error text is rendered by the library.
- **Transformers applied at input time:** `String.trim`, `String.toLower`, etc. run
  during `onInput`, so the stored value is always in transformed form.
- **Lazy rendering:** `Input.build` uses `Html.Lazy.lazy2` for performance.
- **No `<label>` elements:** The label string is used only for `aria-labelledby`,
  not rendered as a visible `<label>` tag.

**Strengths:**
- Extremely minimal (~250 lines), only depends on `elm/core` and `elm/html`.
- Clean builder/pipeline API, idiomatic Elm.
- Phantom type pattern is genuinely elegant and prevents a class of runtime errors.
- Built-in `Html.Lazy` optimization and ARIA accessibility support.
- Transformers at input time are practical.

**Limitations:**
- **Self-described WIP.** The author marks it as work in progress; scope is intentionally limited.
- **All values are untyped strings.** No concept of parsing into typed output.
- **Only `<input>` elements.** No `<textarea>`, `<select>`, `<checkbox>`, or `<radio>`.
- **No visible labels rendered.** Users must create their own `<label>` elements.
- **No error message display.** Only CSS class / ARIA attribute feedback.
- **Single validator per field.** No built-in composition.
- **No field-level state tracking.** No "touched", "dirty", or "submitted" states.
- **No cross-field validation.** No mechanism for dependent field checks.
- **String keys with no uniqueness enforcement.** Duplicate keys silently share state.
- **Whole-dict replacement on every keystroke.** Inefficient for very large forms.

### axelerator/fancy-forms

**Repository:** https://github.com/axelerator/fancy-forms
**Version:** 7.0.1 | **License:** MIT | **Elm:** 0.19.1
**Last commit:** August 2024 | **Stars:** 1
**Status:** Experimental
**Exposed modules:** `FancyForms.Form`, `FancyForms.FormState`, plus 7 widget modules
**Runtime dependencies:** `elm/core`, `elm/html`, `elm/json`

An experimental form library inspired by `dillonkearns/elm-form` that stores **all field
state as JSON values** in a flat `Dict FieldId Value` inside `FormState`. Messages are
also serialized to JSON, enabling a single `Form.Msg` type regardless of form complexity.

#### Core Architecture

```elm
-- All field values stored as JSON in a flat dict
type FormState  -- wraps Dict FieldId Value + blur tracking

-- Single message type for all form events
type Msg  -- internally carries serialized JSON

-- A form definition: combines validation + view
type Form data error
```

7 built-in widget modules provide typed inputs: `FancyForms.Widgets.Text`,
`FancyForms.Widgets.Int`, `FancyForms.Widgets.Float`, `FancyForms.Widgets.Checkbox`,
`FancyForms.Widgets.Dropdown`, `FancyForms.Widgets.RadioButtons`, `FancyForms.Widgets.Date`.

#### Defining a Form

Forms use an **applicative builder pattern** where `field` calls apply arguments one by one:

```elm
myForm : Form Date MyError
myForm =
    Form.form fieldWithErrors daysOfMonthValidator "form-id"
        (\day month year ->
            { view = \formState errors ->
                [ day.view formState
                , month.view formState
                , year.view formState
                ]
            , combine = \formState ->
                { day = day.value formState
                , month = month.value formState
                , year = year.value formState
                }
            }
        )
        |> field .day (integerInput [] |> validate [ greaterThan 0 ])
        |> field .month (integerInput [] |> validate [ greaterThan 0, lesserThan 13 ])
        |> field .year (integerInput [] |> validate [ greaterThan 1900 ])
```

Each `field` call provides both a typed accessor (`.day`) and a widget with validators.
The builder function receives handles with `.view` and `.value` methods per field.
Cross-field validators (like `daysOfMonthValidator`) are passed to `Form.form` and run
after all field-level validators.

#### TEA Integration

Minimal boilerplate -- one Msg variant, one FormState field:

```elm
type alias Model = { formState : FormState }
type Msg = ForForm Form.Msg

init = { formState = Form.init myForm defaultData }

update msg model =
    case msg of
        ForForm formMsg ->
            ( { model | formState = Form.update myForm formMsg model.formState }, Cmd.none )

view model =
    div [] (Form.render ForForm myForm model.formState)

-- Extract current data or check validity:
Form.extract myForm model.formState   -- data record
Form.isValid myForm model.formState   -- Bool
```

#### Notable Features

- **Form composition via `toWidget`:** A complete `Form` can be converted into a widget
  and nested inside another form, enabling composable sub-forms.
- **Dynamic lists:** `listField` supports add/remove operations on collections of sub-forms.
- **Variant fields:** `fieldWithVariants` renders conditional sub-forms based on a selector
  (e.g. Email vs Phone contact method), each variant with its own fields.
- **Custom events:** An escape hatch (`customEvent`/`getCustomEvent`) for emitting
  application-level messages from within form views.
- **Blur-based error display:** Errors only show after a field has been blurred.
- **CSS agnostic:** Views return `List (Html msg)` and error rendering is fully customizable
  via a user-provided error display function.

#### Notable Design Decisions

- **JSON serialization for all state:** Field values and messages are encoded/decoded as JSON.
  This enables a single `Msg` type and `FormState` field regardless of complexity, but
  introduces encode/decode overhead on every user interaction.
- **Auto-generated field IDs:** Fields get sequential string IDs ("0", "1", "2", ...).
  This means reordering fields in the builder can break existing form state.
- **Combined `view` + `combine`:** Like `dillonkearns/elm-form`, validation and view
  are defined together, preventing phantom fields.

**Strengths:**
- Single `Msg` and `FormState` regardless of form size -- minimal TEA wiring.
- Composable: forms can nest via `toWidget`, dynamic lists via `listField`.
- Variant/conditional sub-forms are first-class.
- Good built-in widget selection (text, int, float, checkbox, dropdown, radio, date).
- Blur-based error display gives good UX out of the box.

**Limitations:**
- **JSON serialization overhead** on every interaction (encode/decode per keystroke).
- **No Cmd support in update** -- purely synchronous, no async validation or HTTP.
- **Auto-generated field IDs break on reordering** -- adding/removing fields changes
  all subsequent IDs, which can corrupt persisted state.
- **API still evolving** (7 major versions), so expect breaking changes.
- **Several unimplemented features** noted in the code: external errors, field disabling,
  list reordering.
- **Incompatible with Lamdera** due to functions stored in form definitions (functions
  cannot be serialized across Lamdera's backend/frontend boundary).

### cedricss/elm-form-machine

**Repository:** https://github.com/cedricss/elm-form-machine
**Version:** 1.0.1 | **License:** BSD-3-Clause | **Elm:** 0.19.x
**Last commit:** March 2021 | **Stars:** 1
**Exposed module:** `Form.Machine`
**Runtime dependency:** `rtfeldman/elm-validate`

Models the form lifecycle as a **finite state machine** with explicit states
and transitions, rather than managing individual field values.

#### Core Types

```elm
type State object objectField
    = Unloaded
    | Loading
    | Displaying object
    | Editing object (List (FormError objectField))
    | Failed (List (FormError objectField))

type alias FormError objectField = ( objectField, String )

type Event object objectField customEvents
    = Create
    | Request
    | Display object
    | Edit objectField     -- field identifier carries the new value
    | Save
    | Fail (List (FormError objectField))
    | Perform customEvents
```

The `Config` record defines 6 handlers:

```elm
type alias Config object objectField customEvents msg =
    { badTransition : String -> State object objectField -> ( State object objectField, Cmd msg )
    , default : object
    , perform : customEvents -> State object objectField -> ( State object objectField, Cmd msg )
    , save : Valid object -> Cmd msg   -- requires rtfeldman/elm-validate's Valid wrapper
    , update : objectField -> object -> object
    , validator : Validator ( objectField, String ) object
    }
```

The central function:

```elm
transition : Config ... -> Event ... -> State ... -> ( State ..., Cmd msg )
```

#### State Transitions

```
                 Create              Request
 ──────────> Unloaded ──────────> Loading
                                    │
                              Display obj
                                    │
                                    ▼
                              Displaying obj
                                    │
                              Edit field
                                    │
                                    ▼
                              Editing obj errors
                               │           │
                          Save (valid)   Save (invalid)
                               │           │
                               ▼           ▼
                         Displaying    Failed errors
                          (+ Cmd)
```

#### TEA Integration

```elm
type alias Model = { form : Form.Machine.State User UserField }

type Msg
    = FormEvent (Form.Machine.Event User UserField CustomEvent)
    | ...

update msg model =
    case msg of
        FormEvent event ->
            let ( newState, cmd ) = Form.Machine.transition config event model.form
            in ( { model | form = newState }, cmd )

view model =
    case model.form of
        Form.Machine.Displaying user -> viewDisplay user
        Form.Machine.Editing user errors -> viewEditForm user errors
        Form.Machine.Failed errors -> viewErrors errors
        _ -> -- loading states
```

#### Notable Design Decisions

- **`save` requires `Valid object`:** The `save` handler's signature uses
  `rtfeldman/elm-validate`'s `Valid` wrapper, making it a compile-time guarantee
  that unvalidated data cannot be saved. The library calls `Validate.validate`
  internally before invoking `save`.
- **Field identifiers carry values:** `Edit (FieldName "Alice")` rather than
  `Edit FieldName "Alice"` -- the field variant itself wraps the new value.
- **Explicit bad transition handling:** Illegal transitions (e.g. `Save` from `Unloaded`)
  are routed to a `badTransition` callback rather than silently ignored.
- **`Perform customEvents` escape hatch:** Extensible for domain-specific events
  outside the standard form lifecycle.

**Strengths:**
- Clean conceptual model: form lifecycle as an explicit state machine with well-defined
  transitions prevents impossible states (e.g. saving while unloaded).
- `Valid` wrapper from `rtfeldman/elm-validate` ensures validated data at the type level.
- Supports async workflows naturally (Loading -> Display, Save -> Cmd).
- Illegal transitions are explicitly handled, not silently swallowed.

**Limitations:**
- **No view layer at all.** Zero view helpers -- all HTML is the user's responsibility.
- **No "saving in progress" state.** After successful validation, the state jumps
  directly to `Displaying` with a `Cmd` -- there is no `Saving` state to show a spinner.
- **No per-field "touched" tracking.** Errors are shown for all fields immediately
  in the `Editing` state.
- **Single-object forms only.** No sub-forms, form lists, or wizard support.
- **Hard coupling to `rtfeldman/elm-validate`.** No way to swap validation approaches.
- **Field-carries-value pattern is unusual.** Defining `type UserField = FieldName String | FieldAge Int`
  means field identifiers are not simple enums -- they carry data, which complicates
  pattern matching and error display.
- **README example has type inconsistencies.** The documented example does not
  fully type-check, suggesting incomplete documentation.

### arowM/elm-form-decoder

**Repository:** https://github.com/arowM/elm-form-decoder
**Version:** 1.4.0 | **License:** MIT | **Elm:** 0.19.x
**Stars:** 124 | **Created:** April 2019 | **Last Elm code change:** August 2020
**Exposed module:** `Form.Decoder`
**Runtime dependencies:** `elm/core` only (zero third-party deps)
**Blog post:** https://sakurachan.info/posts/2019/form-decoding/
**Live demo:** https://arowm.github.io/elm-form-decoder/

The core thesis is "form **decoding**, not form **validation**" -- the same decoder
simultaneously validates user inputs and converts them into typed domain values,
so validation and construction can never fall out of sync.

#### Core Types

```elm
-- A decoder that consumes `input`, may produce errors of type `err`,
-- and on success yields a value of type `a`.
type Decoder input err a
    = Decoder (input -> Result (List err) a)

-- A decoder that validates but produces no output value.
type alias Validator input err =
    Decoder input err ()
```

The `Decoder` type is an opaque wrapper around `input -> Result (List err) a`.
Errors are always collected in a `List`, enabling error accumulation across fields.

#### Full API (Form.Decoder module)

**Running decoders:**

| Function | Signature | Purpose |
|---|---|---|
| `run` | `Decoder input err a -> input -> Result (List err) a` | Execute decoder, get `Ok value` or `Err errors` |
| `errors` | `Decoder input err a -> input -> List err` | Get error list (empty if valid) |

**Primitive decoders:**

| Function | Signature | Purpose |
|---|---|---|
| `identity` | `Decoder input never input` | Pass-through, input becomes output |
| `always` | `a -> Decoder input never a` | Always succeed with constant value |
| `fail` | `err -> Decoder input err a` | Always fail with given error |
| `int` | `err -> Decoder String err Int` | Parse string to int |
| `float` | `err -> Decoder String err Float` | Parse string to float |

**Primitive validators:**

| Function | Signature | Purpose |
|---|---|---|
| `minBound` | `err -> comparable -> Validator comparable err` | Minimum bound check |
| `maxBound` | `err -> comparable -> Validator comparable err` | Maximum bound check |
| `minBoundWith` | `(a -> a -> Order) -> err -> a -> Validator a err` | Min bound with custom comparison |
| `maxBoundWith` | `(a -> a -> Order) -> err -> a -> Validator a err` | Max bound with custom comparison |
| `minLength` | `err -> Int -> Validator String err` | Minimum string length |
| `maxLength` | `err -> Int -> Validator String err` | Maximum string length |

**Custom decoders:**

| Function | Signature | Purpose |
|---|---|---|
| `custom` | `(input -> Result (List err) a) -> Decoder input err a` | Build decoder from raw function |

**Validation helpers:**

| Function | Signature | Purpose |
|---|---|---|
| `assert` | `Validator a err -> Decoder input err a -> Decoder input err a` | Attach a validator to a decoder |
| `when` | `(a -> Bool) -> Validator a err -> Validator a err` | Conditional validation (if true) |
| `unless` | `(a -> Bool) -> Validator a err -> Validator a err` | Conditional validation (if false) |

**Form composition (applicative pipeline):**

| Function | Signature | Purpose |
|---|---|---|
| `top` | `f -> Decoder i err f` | Start a pipeline with a constructor |
| `field` | `Decoder i err a -> Decoder i err (a -> b) -> Decoder i err b` | Apply next field (accumulates errors) |
| `lift` | `(j -> i) -> Decoder i err a -> Decoder j err a` | Change input type via accessor function |
| `map` | `(a -> b) -> Decoder input x a -> Decoder input x b` | Transform output |
| `map2`..`map5` | Standard applicative mapN | Combine 2-5 decoders |
| `mapError` | `(x -> y) -> Decoder input x a -> Decoder input y a` | Transform error type |

**Advanced:**

| Function | Signature | Purpose |
|---|---|---|
| `pass` | `Decoder b x c -> Decoder a x b -> Decoder a x c` | Chain: output of first feeds input of second |
| `with` | `(i -> Decoder i err a) -> Decoder i err a` | Inspect input to choose decoder (conditional/branching) |
| `andThen` | `(a -> Decoder input x b) -> Decoder input x a -> Decoder input x b` | Sequence: decoded value determines next decoder |

**Collection helpers:**

| Function | Signature | Purpose |
|---|---|---|
| `list` | `Decoder a err b -> Decoder (List a) err (List b)` | Decode a list of inputs |
| `listOf` | `Decoder a err b -> Decoder (List a) (Int, err) (List b)` | Same, with indexed errors |
| `array` | `Decoder a err b -> Decoder (Array a) err (Array b)` | Decode an array of inputs |
| `arrayOf` | `Decoder a err b -> Decoder (Array a) (Int, err) (Array b)` | Same, with indexed errors |

#### Defining a Form

The pattern has four layers:

**1. Domain type (the decoded output):**

```elm
type alias Goat =
    { name : Name
    , age : Age
    , horns : Horns
    , contact : Contact
    , message : Maybe Message
    }
```

**2. Form state type (raw user input -- all strings):**

```elm
type alias RegisterForm =
    { name : Input       -- opaque wrapper around String
    , age : Input
    , horns : Input
    , email : Input
    , phone : Input
    , contactType : Select
    , message : Input
    }
```

**3. Error type (one variant per possible error):**

```elm
type Error
    = NameError Name.Error
    | NameRequired
    | AgeError Age.Error
    | AgeRequired
    | HornsError Horns.Error
    | HornsRequired
    ...
```

**4. Per-field decoders, composed into a form decoder:**

Each field gets its own decoder from `String` to a domain type:

```elm
-- Field-level: String -> Age
decoder : Decoder String Error Age
decoder =
    Decoder.int InvalidInt               -- parse string to int
        |> Decoder.assert (Decoder.minBound Negative 0)  -- validate >= 0
        |> Decoder.map Age               -- wrap in domain type
```

Then lift to form level and compose:

```elm
-- Form-level: RegisterForm -> Goat
decoder : Decoder RegisterForm Error Goat
decoder =
    Decoder.map5 Goat
        decoderName
        decoderAge
        decoderHorns
        decoderContact
        decoderMessage

decoderAge : Decoder RegisterForm Error Age
decoderAge =
    Age.decoder                          -- Decoder String Age.Error Age
        |> Decoder.mapError AgeError     -- unify error types
        |> Input.required AgeRequired    -- handle empty = required error
        |> Decoder.lift .age             -- extract from RegisterForm
```

The `top`/`field` pipeline is an alternative to `mapN` that scales to any number of fields:

```elm
decoder =
    Decoder.top Goat
        |> Decoder.field decoderName
        |> Decoder.field decoderAge
        |> Decoder.field decoderHorns
        |> Decoder.field decoderContact
        |> Decoder.field decoderMessage
```

**5. Conditional/branching decoding with `andThen` and `with`:**

```elm
decoderContact : Decoder RegisterForm Error Contact
decoderContact =
    ContactType.decoder
        |> Decoder.mapError ContactTypeError
        |> Select.required ContactTypeRequired
        |> Decoder.lift .contactType
        |> Decoder.andThen
            (\ctype ->
                case ctype of
                    UseEmail -> Decoder.map ContactEmail decoderEmail
                    UsePhone -> Decoder.map ContactPhone decoderPhone
            )
```

**6. Optional fields:**

```elm
-- Input.optional checks: if empty -> Ok Nothing, otherwise -> map Just (run decoder)
decoderMessage : Decoder RegisterForm Error (Maybe Message)
decoderMessage =
    Message.decoder
        |> Decoder.mapError MessageError
        |> Input.optional             -- Decoder Input err (Maybe Message)
        |> Decoder.lift .message
```

#### TEA Integration

The library is **completely UI-agnostic** -- it provides no Msg, Model, update, or view helpers.
Integration with TEA is entirely manual:

**Model:** Store the form state record alongside application state.

```elm
type alias Model =
    { registerForm : Goat.RegisterForm
    , goats : List Goat
    , pageState : PageState  -- Registering | FixingRegisterErrors | ShowGoats
    }
```

**Msg:** One message per field (standard Elm pattern).

```elm
type Msg
    = ChangeName String
    | ChangeAge String
    | ChangeHorns String
    | SubmitRegister
```

**Update:** Simple field assignment; on submit, run the decoder.

```elm
update msg model =
    case msg of
        ChangeName name ->
            ( { model | registerForm = { form | name = Input.fromString name } }, Cmd.none )

        SubmitRegister ->
            case Decoder.run Goat.decoder model.registerForm of
                Ok goat ->
                    ( { model | goats = goat :: model.goats, pageState = ShowGoats }, Cmd.none )
                Err _ ->
                    ( { model | pageState = FixingRegisterErrors }, Cmd.none )
```

**View:** Use `Decoder.errors` or `Decoder.run` to display per-field or form-level errors.

```elm
-- Per-field inline errors
inputErrorField decoder input =
    case Decoder.run decoder (Input.toString input) of
        Ok _ -> Html.text ""
        Err errs -> div [ class "errors" ] (List.map viewError errs)

-- Form-level: check if specific error is present
hasError err =
    case Decoder.run Goat.decoder registerForm of
        Ok _ -> False
        Err errs -> List.member err errs
```

#### Notable Design Decisions

- **"Decode, don't validate" philosophy:** Validation and type conversion are unified
  in a single `Decoder`. If `run` succeeds, you have a correctly typed domain value.
  There is no possible state where validation passes but construction fails.

- **Applicative error accumulation via `field`:** The `field` combinator collects errors
  from all branches rather than short-circuiting. If name and age both fail, you get
  both error lists concatenated. This is implemented by running both decoders on the
  same input and merging `Err` lists.

- **`Decoder` is `Json.Decode.Decoder`-inspired:** The API mirrors `elm/json`'s decoder
  pattern (`map`, `andThen`, `field`), making it familiar to Elm developers. The key
  difference is that it decodes from arbitrary input types (form records, strings)
  rather than JSON values.

- **`Validator` as a type alias:** `Validator input err = Decoder input err ()` -- validators
  are just decoders that produce unit. This means all decoder combinators work on
  validators too, with no separate validation API.

- **`lift` for composition:** Instead of `Json.Decode.field` (which uses string keys),
  `lift` takes an accessor function (`.fieldName`), giving compile-time safety.

- **`pass` for sequential decoding chains:** Unlike `andThen` (which re-reads the original
  input), `pass` feeds the output of one decoder as the input to the next, enabling
  pipelines like `identity |> assert validator |> pass (int err) |> assert (minBound err n)`.

- **No form state management:** The library deliberately manages no state. It is purely
  a decoding/validation toolkit. The user owns the form model, Msg type, and update logic.

- **Per-field decoder modularity:** The sample app demonstrates the recommended pattern:
  each field gets its own module (`Goat.Name`, `Goat.Age`, `Goat.Horns`) with its own
  `Error` type, `decoder`, and `errorField` display function, composed at the form level
  via `mapError` and `lift`.

#### Strengths

- **Zero dependencies** beyond `elm/core`. No framework lock-in.
- **Familiar decoder pattern.** Elm developers already know `Json.Decode`; this is the same
  pattern applied to forms.
- **Error accumulation by default.** The `field`/`mapN` combinators collect all errors
  across all fields in a single pass.
- **Highly composable.** Decoders compose via `lift`, `map`, `andThen`, `with`, `pass`.
  Field decoders, form decoders, and validators all share the same type.
- **Conditional/branching forms** are natural with `andThen` and `with` -- e.g. decode
  different contact info based on a select field.
- **List/array support** built in with index-aware error reporting (`listOf`, `arrayOf`).
- **UI-agnostic.** Works with elm-ui, elm-css, plain HTML, or any rendering approach.
- **Doctested.** Every function in the source has `elm-verify-examples`-compatible doc tests.
- **Lightweight.** Single module, ~450 lines of source.
- **124 GitHub stars** -- well-known in the Elm community.

#### Limitations

- **No form state management.** Unlike `dwayne/elm-form` or `choonkeat/formdata`, there
  is no form lifecycle, no "submitted" state, no dirty/visited tracking. All of this
  must be built by the user.
- **One Msg per field.** The library provides no mechanism to reduce Msg boilerplate.
  Each field typically requires its own `Change*` message.
- **No built-in view helpers.** Every project must create its own input components.
  The sample app builds a custom `Atom.Input` and `Atom.Select` module.
- **No built-in required/optional field handling.** The sample app builds `Input.required`
  and `Input.optional` helpers; these are not part of the library itself.
- **`errors` function re-runs the full decoder.** Calling `Decoder.errors` for per-field
  display in the view runs the decoder again each time. For complex forms, this could
  be wasteful (though Elm's virtual DOM diffing and lazy evaluation mitigate this).
- **No async/server-side validation.** No mechanism for checking uniqueness or other
  server-dependent validations.
- **Error types must be unified manually.** Each field module defines its own `Error` type;
  composing them requires wrapping with `mapError` and a top-level `Error` union type with
  one variant per sub-error. This is verbose for large forms.

---

## Comparison

| Feature | dwayne/elm-form | hecrj/composable-form | etaque/elm-form | dillonkearns/elm-form | choonkeat/formdata | arowM/elm-form-decoder | cekrem/elm-form | axelerator/fancy-forms | cedricss/elm-form-machine |
|---|---|---|---|---|---|---|---|---|---|
| **Type safety** | Strong (typed accessors) | Strong (typed values) | Weak (string paths) | Strong (typed field refs) | Strong (union-type keys) | Strong (typed accessors via `lift`) | Weak (string dict keys) | Strong (typed accessors) | Strong (typed field union) |
| **UI coupling** | None (bring your own) | Decoupled (Form.View) | Decoupled (Form.Input) | Combined (combine + view) | None (bring your own) | None (bring your own) | Coupled (renders `<input>`) | Combined (view + combine) | None (bring your own) |
| **Error accumulation** | Yes (Validation type) | No (Result) | No (Result) | No (Result) | Manual (user-written parser) | Yes (`field` collects all errors) | No (single validator) | Yes (field + cross-field) | Via elm-validate |
| **Cross-field validation** | Accessor modify hook | andThen, meta | andThen, customValidation | map2, andThen | In parseDontValidate fn | `with`, `andThen` | No | Form-level validators | Via elm-validate |
| **Dynamic form lists** | Form.List module | Form.list | Built-in append/remove | Form.dynamic | No | `list`, `listOf`, `array`, `arrayOf` | No | `listField` | No |
| **Form lifecycle** | Manual | Built-in (Idle/Loading/...) | Manual | Submission tracking | Built-in (Invalid/Valid/Submitting) | Manual | Manual | Manual | Built-in state machine (5 states) |
| **Server-side errors** | No | No | No | Yes (ServerResponse) | No | No | No | No (planned) | No |
| **elm-ui compatible** | Yes (no UI opinion) | No (HTML-based view) | No (HTML-based view) | No (semantic HTML) | Yes (no UI opinion) | Yes (no UI opinion) | No (renders HTML) | Yes (returns Html list) | Yes (no UI opinion) |
| **Visited-field tracking** | Via elm-field isDirty | No | No | No | Built-in (onVisited/visitedErrors) | No (manual) | No | Yes (blur-based) | No |
| **Msg boilerplate** | One per field | One (onChange) | One (Form.Msg) | One (Form.Msg) | 2-4 total (field key as param) | One per field | Two (FormChanged, Submit) | One (Form.Msg) | One per event |
| **Dependencies** | elm-validation | elm/core only | elm/core only | elm/core only | any-dict | elm/core only | elm/core, elm/html | elm/core, elm/html, elm/json | elm-validate |
| **Version / Last commit** | v1.0.0 (Dec 2025) | v8.0.1 (Nov 2019) | v4.0.0 (archived May 2024) | v3.0.1 (Oct 2025) | v2.1.0 (Oct 2021) | v1.4.0 (Aug 2020) | v1.1.1 (Dec 2025, WIP) | v7.0.1 (Aug 2024) | v1.0.1 (Mar 2021) |

## elm-ui Compatible Packages

Five of the nine packages are UI-agnostic: they expose no `Html msg` types in their
public API and handle only form state, validation, and data extraction. This makes them
directly usable with elm-ui (or any other view library) without wrapping or adapter code.

The other four (`hecrj/composable-form`, `etaque/elm-form`, `dillonkearns/elm-form`,
`cekrem/elm-form`) produce or expect `Html msg` values, tying them to `elm/html`.
`axelerator/fancy-forms` returns `List (Html msg)` from its render function, so while
it is CSS-agnostic, its view types are still `Html`-based.

### Focused Comparison

| Feature | dwayne/elm-form | arowM/elm-form-decoder | choonkeat/formdata | cedricss/elm-form-machine |
|---|---|---|---|---|
| **What it manages** | Field state + validation | Validation/decoding only | Field state + validation | Form lifecycle (state machine) |
| **Type safety** | Typed accessors | Typed accessors via `lift` | Union-type keys | Typed field union |
| **Error accumulation** | Yes (Validation type) | Yes (`field` combinator) | Manual (user parser) | Via elm-validate |
| **Cross-field validation** | Accessor modify hook | `with`, `andThen` | In parseDontValidate fn | Via elm-validate |
| **Dynamic form lists** | `Form.List` module | `list`, `listOf` | No | No |
| **Form lifecycle** | Manual | Manual | Built-in (Invalid/Valid/Submitting) | Built-in (5-state machine) |
| **Visited/dirty tracking** | Via elm-field `isDirty` | Manual | Built-in (`onVisited`) | No |
| **Msg boilerplate** | One per field | One per field | 2-4 total | One per event |
| **Dependencies** | elm-validation | elm/core only | any-dict | elm-validate |
| **API surface** | 2 modules (~200 LOC) | 1 module (~450 LOC) | 1 module (~15 fns) | 1 module (5 types + 1 fn) |

### Key Differences

**`dwayne/elm-form`** is the most complete: it manages field state, supports nested
sub-forms and dynamic lists via `Form.List`, and provides error-accumulating validation.
The trade-off is accessor boilerplate (a `{ get, modify }` record per field).

**`arowM/elm-form-decoder`** is the most composable for validation logic: decoders and
validators share the same type, compose via `lift`/`map`/`andThen`/`pass`, and support
lists/arrays with indexed errors. It deliberately manages no state -- you bring your own
model, Msg, and update. This makes it the lightest-weight option (zero dependencies
beyond `elm/core`) but means you build all form infrastructure yourself.

**`choonkeat/formdata`** is the most economical in Msg boilerplate: a single `OnInput k String`
message handles all fields because the field key is a parameter, not a separate Msg variant.
It also has built-in visited-field tracking and submission state. The trade-off is no
composability (no sub-forms or lists) and a verbose manual `parseDontValidate` function.

**`cedricss/elm-form-machine`** takes a different angle entirely: it manages the form
*lifecycle* (Unloaded -> Loading -> Displaying -> Editing -> Failed) rather than individual
fields. The `save` handler requires `rtfeldman/elm-validate`'s `Valid` wrapper, ensuring
validated data at the type level. It is complementary to the other packages -- you could
use `elm-form-machine` for lifecycle and `elm-form-decoder` for field validation, for example.

### Pairing Patterns

Since all four are UI-agnostic, they can be combined:

- **`dwayne/elm-form` + elm-ui:** The most natural pairing. `Form.get` reads field values
  for elm-ui inputs, `Form.modify` updates them. Validation errors from `Form.validateAsResult`
  drive conditional `Ui.text` error messages.

- **`arowM/elm-form-decoder` + elm-ui:** Define decoders separately, store raw form state
  in a plain record, and call `Decoder.errors` per field in the elm-ui view to display
  inline errors. Good for projects that want maximum separation between form logic and UI.

- **`choonkeat/formdata` + elm-ui:** `FormData.value key formData` reads field values for
  elm-ui inputs. `FormData.visitedErrors` filters errors for display. The minimal Msg
  footprint keeps the update function small.

- **`cedricss/elm-form-machine` + any of the above:** Use the state machine for lifecycle
  transitions and pattern-match on the `State` type in your elm-ui view, while using
  one of the other libraries for field-level validation within the `Editing` state.

## Recommendation

For new Elm projects, **`dwayne/elm-form`** is the best choice when:

- You want full control over the UI (especially with elm-ui)
- You value error accumulation (all errors shown at once)
- You need composable/nestable forms with dynamic lists
- You want a minimal, understandable library

**`dillonkearns/elm-form`** is the better choice when:

- You use `elm-pages` or need progressive enhancement
- You want server-side validation error integration
- You prefer a single definition that binds validation and view together

**`arowM/elm-form-decoder`** is a strong choice when:

- You want a `Json.Decode`-like API applied to forms (familiar pattern for Elm developers)
- You want error accumulation with zero third-party dependencies
- You need conditional/branching form logic (the `with`/`andThen` combinators are powerful)
- You prefer maximum composability -- decoders and validators share the same type

The remaining packages fill narrower niches:

- **`hecrj/composable-form`** has the cleanest applicative builder pattern with built-in
  form lifecycle states and minimal Msg boilerplate, but bundles its own HTML view layer.
- **`etaque/elm-form`** is the most natural fit for dynamic/data-driven forms thanks to
  string-path field addressing and built-in view helpers, but lacks type safety at the field level.
- **`choonkeat/formdata`** combines union-type keys with minimal Msg boilerplate and
  built-in visited-field tracking, but lacks composability (no sub-forms or dynamic lists).
- **`axelerator/fancy-forms`** has good widget coverage and composability (sub-forms, lists,
  variant fields), but its JSON serialization overhead and still-evolving API (7 major versions)
  are trade-offs to consider.
- **`cedricss/elm-form-machine`** models the form lifecycle as a finite state machine with
  compile-time validated-data guarantees via `rtfeldman/elm-validate`. It focuses on lifecycle
  rather than field management -- useful as a pattern, but covers a narrower scope than the others.
- **`cekrem/elm-form`** demonstrates a clean phantom-type pattern for compile-time input safety,
  but is self-described as WIP and currently only supports `<input>` elements with untyped string values.

For simple forms (fewer than 5 fields), many Elm developers skip form libraries entirely
and use plain TEA with manual validation functions.
