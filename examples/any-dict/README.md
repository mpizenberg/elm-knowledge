# Dicts with Custom Keys using any-dict

This example demonstrates [turboMaCk/any-dict](https://github.com/turboMaCk/any-dict) for using custom union types as dictionary keys. It implements a fruit inventory tracker with a `Fruit` type as keys.

## How it works

Elm's built-in `Dict` requires keys to be `comparable` (Int, Float, Char, String, or tuples/lists of those). You cannot use a custom type like `type Fruit = Apple | Banana | Orange | Mango` as a `Dict` key.

`AnyDict` solves this by requiring a `toComparable` function (`k -> comparable`) when creating the dictionary. This function converts each key to a comparable value used internally for ordering.

```elm
fruitToString : Fruit -> String
fruitToString fruit =
    case fruit of
        Apple -> "Apple"
        Banana -> "Banana"
        Orange -> "Orange"
        Mango -> "Mango"

inventory : AnyDict String Fruit Int
inventory =
    Dict.Any.empty fruitToString
```

The app lets you select a fruit, add/remove quantities, and displays the inventory as a table.

## Key patterns

- **Create**: `Dict.Any.empty toComparable`, `Dict.Any.fromList toComparable list`, `Dict.Any.singleton key value toComparable`
- **Query**: `Dict.Any.get key dict`, `Dict.Any.member key dict`
- **Modify**: `Dict.Any.insert key value dict`, `Dict.Any.update key fn dict`, `Dict.Any.remove key dict`
- **Iterate**: `Dict.Any.toList dict`, `Dict.Any.keys dict`, `Dict.Any.foldl fn acc dict`

## Gotchas

- **`toComparable` is provided once**: You pass it when creating the dict (`empty`, `fromList`, `singleton`). All subsequent operations use the stored function.
- **`toComparable` must be injective**: Every distinct key must produce a different comparable value. If two keys map to the same comparable, they will overwrite each other.
- **Don't use `==` on AnyDict**: `AnyDict` stores the `toComparable` function internally. Using `==` to compare two `AnyDict` values causes a runtime exception. Use `Dict.Any.equal` instead.

## Running the example

```sh
elm make src/Main.elm --output=static/elm.js
cd static
python3 -m http.server 8000
```

Open `http://localhost:8000` in your browser.

## Project structure

```
any-dict/
  elm.json          -- Elm dependencies (turboMaCk/any-dict)
  src/Main.elm      -- Elm app: fruit inventory with custom-keyed dict
  static/
    index.html      -- HTML shell (no ports needed)
    elm.js          -- compiled Elm output (generated)
```
