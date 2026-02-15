# elm-ui v2 API Reference

This is a detailed reference for [elm-ui v2](https://github.com/mdgriffith/elm-ui/tree/2.0).

## Module structure

The root module is now `Ui` (was `Element`). Background and border are merged into `Ui`.
New modules: `Ui.Prose`, `Ui.Anim`, `Ui.Gradient`, `Ui.Responsive`, `Ui.Layout`, `Ui.Shadow`, `Ui.Table`.
`Element.Region` becomes `Ui.Accessibility`.

| Module | Purpose |
|---|---|
| `Ui` | Layout (`el`, `row`, `column`), sizing, colors, background, border, positioning, links, images |
| `Ui.Font` | Typography: families, sizes, weights, OpenType variants, alignment |
| `Ui.Prose` | Paragraphs, semantic lists (`numbered`, `bulleted`), typographic chars (`emDash`, `quote`) |
| `Ui.Input` | Buttons, text fields, checkboxes, sliders, `chooseOne` (was `radio`) |
| `Ui.Anim` | CSS transitions, keyframe animations, springs, state-driven timelines |
| `Ui.Responsive` | Breakpoint-based responsive design via CSS media queries (no subscriptions) |
| `Ui.Table` | Data tables with sorting, sticky headers, column visibility |
| `Ui.Layout` | `rowWithConstraints` for CSS Grid layouts (advanced) |
| `Ui.Shadow` | Box, inner, and text shadows (supports multiple shadows) |
| `Ui.Gradient` | Linear, radial, conic gradients (for backgrounds, borders, and text) |
| `Ui.Events` | Mouse, focus, typed keyboard events (`onKey enter msg`) |
| `Ui.Accessibility` | ARIA landmarks, headings, live regions |

## Layout

Three primitives: `el` (single child), `row` (horizontal), `column` (vertical).
No margins — use `padding` on containers and `spacing` on parents for gaps between children.

```elm
column [ spacing 20, padding 16 ]
    [ row [ spacing 12 ] [ icon, title ]
    , body
    ]
```

Sizing: `shrink` (content-sized), `fill` (expand), `portion n` (proportional weight).
Min/max are separate attributes: `width fill, widthMin 200, widthMax 800`.

Alignment: `centerX`/`alignLeft`/`alignRight` position a child within its parent.
`contentCenterX`/`contentCenterY` (new) align all children within a container.

Wrapping: `row [ wrap, spacing 10 ] [...]` (replaces v1's `wrappedRow`).

## Styling

Attribute composition — `noAttr` (identity), `attrs` (batch), `attrIf` (conditional):

```elm
cardStyle : Attribute msg
cardStyle = attrs [ padding 20, rounded 8, background (rgb 255 255 255) ]

el [ cardStyle, attrIf isSelected (borderColor (rgb 0 120 255)) ] content
```

Colors use 0–255 integers (not 0.0–1.0 floats): `rgb 60 181 204`, `rgba 0 0 0 0.1`.

Background: `Ui.background color`, `Ui.backgroundGradient [gradient]`.
Border: `Ui.border width`, `Ui.borderColor color`, `Ui.rounded px`, `Ui.circle`.
Font: `Ui.Font.color`, `Ui.Font.size`, `Ui.Font.bold`, `Ui.Font.family [typeface "Inter", sansSerif]`.

Links and buttons are now attributes, not elements:

```elm
el [ Ui.link "/about" ] (text "About")
el [ Ui.Input.button ClickMsg, padding 12, background (rgb 0 120 255) ] (text "Click")
```

Labels for inputs return `{ element, id }` — place the element in your view, pass the id to the input:

```elm
let nameLabel = Ui.Input.label "name" [] (text "Name")
in column [] [ nameLabel.element, Ui.Input.text [] { ..., label = nameLabel.id } ]
```

## Responsive design (pure CSS, no subscriptions)

Define breakpoints once with a custom type. No JS flags or window resize subscriptions needed.

```elm
type Screen = Mobile | Tablet | Desktop
screens = Ui.Responsive.breakpoints Mobile [ (768, Tablet), (1200, Desktop) ]
```

Pass to layout via `Ui.layout (Ui.default |> Ui.withBreakpoints screens) [] view`.

Key responsive attributes:
- `Ui.Responsive.rowWhen screens [Tablet, Desktop]` — column on mobile, row on larger screens
- `Ui.Responsive.fontSize screens (\s -> ...)` — responsive font size
- `Ui.Responsive.fluid 14 20` — smoothly interpolate between 14px and 20px across the breakpoint range
- `Ui.Responsive.visible screens [Desktop]` — show only at specific breakpoints

## Animation

Built-in via `Ui.Anim`, but internally depends on an unpublished [elm-animator v2](https://github.com/mdgriffith/elm-animator/tree/v2) which must be embedded alongside elm-ui.
Requires wiring `Ui.Anim.init`/`Ui.Anim.update` through TEA.

```elm
-- Hover effect (CSS transition)
el [ Ui.Anim.hovered (Ui.Anim.ms 200) [ Ui.Anim.scale 1.05, Ui.Anim.opacity 0.9 ] ] content

-- Keyframe animation
el [ Ui.Anim.keyframes [ Ui.Anim.loop [ Ui.Anim.step (Ui.Anim.ms 1000) [ Ui.Anim.rotation 6.28 ] ] ] ] icon

-- Presets: spinning, pulsing, bouncing, pinging
el [ Ui.Anim.spinning (Ui.Anim.ms 1000) ] spinner
```

Easing: `linear`, `bezier`, `spring { wobble, quickness }`.

## Typography

OpenType variant support: `Ui.Font.variants [ tabularNumbers, ligatures, smallCaps ]`.
Fine control: `lineHeight`, `letterSpacing`, `wordSpacing`, `exactWhitespace`, `noWrap`.
Gradient text: `Ui.Font.gradient gradient`.
Include external fonts in HTML `<head>` (`Font.external` removed in v2).

## Key migration gotchas (v1 to v2)

- `Element` -> `Ui`, `Element.Background`/`Element.Border` -> `Ui`
- `rgb` takes `Int` 0-255 (was `Float` 0-1). v1's `rgb255` is now just `rgb`
- `button` and `link` are attributes, not elements
- `paragraph` moved to `Ui.Prose.paragraph`
- `fillPortion` -> `portion`, `paddingEach` -> `paddingWith`, `wrappedRow` -> `row [ wrap ]`
- `Input.radio` -> `Input.chooseOne` (takes a layout function as first arg)
- `Input.slider` -> `Input.sliderHorizontal` / `Input.sliderVertical`
- `Border.shadow` (single) -> `Ui.Shadow.shadows` (list)
