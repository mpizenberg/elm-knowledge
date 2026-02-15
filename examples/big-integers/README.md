# Big Integers with elm-natural

This example demonstrates arbitrary-precision arithmetic in Elm using [dwayne/elm-natural](https://github.com/dwayne/elm-natural). It includes a factorial calculator and a base converter.

## How it works

Elm's built-in `Int` type is a 64-bit float under the hood, so it overflows at 21! (exceeds `2^53 - 1`). The `Natural` type from `dwayne/elm-natural` supports arbitrarily large non-negative integers, limited only by available memory.

The app has two sections:
- **Factorial calculator**: Enter n, compute n! with full precision. Try n=100 to see a 158-digit result.
- **Base converter**: Enter a decimal number and convert to binary, octal, or hexadecimal.

## Key patterns

- **Creating values**: `Natural.fromInt` (returns `Maybe`, rejects negatives), `Natural.fromSafeInt` (returns `zero` for invalid input, useful for constants), `Natural.fromString` (supports `0b`, `0o`, `0x` prefixes)
- **Arithmetic**: `Natural.add`, `Natural.mul`, `Natural.sub` (saturating), `Natural.divModBy`, `Natural.exp`
- **Display**: `Natural.toString`, `Natural.toHexString`, `Natural.toBinaryString`, `Natural.toOctalString`
- **Tail-recursive factorial**: Uses an accumulator pattern for stack safety

## Gotchas

- **Saturating subtraction**: `Natural.sub a b` returns `zero` when `b > a`, not a negative number
- **`toInt` wraps**: `Natural.toInt n` returns `n mod (maxSafeInt + 1)`, silently wrapping large values
- **Equality works**: Unlike `AnyDict`, you can use `==` and `/=` to compare `Natural` values

## Running the example

```sh
elm make src/Main.elm --output=static/elm.js
cd static
python3 -m http.server 8000
```

Open `http://localhost:8000` in your browser.

## Project structure

```
big-integers/
  elm.json          -- Elm dependencies (dwayne/elm-natural, dwayne/elm-integer)
  src/Main.elm      -- Elm app: factorial calculator, base converter
  static/
    index.html      -- HTML shell (no ports needed)
    elm.js          -- compiled Elm output (generated)
```
