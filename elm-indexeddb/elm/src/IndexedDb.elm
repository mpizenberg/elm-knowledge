module IndexedDb exposing
    ( Schema, schema, withStore
    , Store, defineStore, withKeyPath, withAutoIncrement
    , ExplicitKey, InlineKey, GeneratedKey
    , Db, open, deleteDatabase
    , Key(..)
    , get, getAll, getAllKeys, count
    , put, add
    , putAt, addAt
    , insert
    , delete, clear
    , putMany, putManyAt, insertMany, deleteMany
    , Error(..)
    )

{-| IndexedDB support for Elm via elm-concurrent-task.


# Schema

@docs Schema, schema, withStore
@docs Store, defineStore, withKeyPath, withAutoIncrement
@docs ExplicitKey, InlineKey, GeneratedKey


# Database

@docs Db, open, deleteDatabase


# Keys

@docs Key


# Read Operations

@docs get, getAll, getAllKeys, count


# Write Operations — InlineKey stores

@docs put, add


# Write Operations — ExplicitKey stores

@docs putAt, addAt


# Write Operations — GeneratedKey stores

@docs insert


# Delete Operations

@docs delete, clear


# Batch Operations

@docs putMany, putManyAt, insertMany, deleteMany


# Errors

@docs Error

-}

import ConcurrentTask exposing (ConcurrentTask)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)



-- PHANTOM TYPES


{-| Marker type for stores where the key must be provided explicitly.
-}
type ExplicitKey
    = ExplicitKey


{-| Marker type for stores where the key is extracted from the value via keyPath.
-}
type InlineKey
    = InlineKey


{-| Marker type for stores where the key is auto-generated.
-}
type GeneratedKey
    = GeneratedKey



-- STORE


{-| A store definition with a phantom type `k` indicating its key configuration.
-}
type Store k
    = Store
        { name : String
        , keyPath : Maybe String
        , autoIncrement : Bool
        }


{-| Define a new store with explicit keys (no keyPath, no autoIncrement).

    rawStore : Store ExplicitKey
    rawStore =
        defineStore "raw"

-}
defineStore : String -> Store ExplicitKey
defineStore name =
    Store { name = name, keyPath = Nothing, autoIncrement = False }


{-| Set a keyPath on a store, making it an InlineKey store.

    todosStore : Store InlineKey
    todosStore =
        defineStore "todos"
            |> withKeyPath "id"

-}
withKeyPath : String -> Store ExplicitKey -> Store InlineKey
withKeyPath path (Store config) =
    Store { config | keyPath = Just path }


{-| Enable auto-increment on a store, making it a GeneratedKey store.

    cacheStore : Store GeneratedKey
    cacheStore =
        defineStore "cache"
            |> withAutoIncrement

-}
withAutoIncrement : Store ExplicitKey -> Store GeneratedKey
withAutoIncrement (Store config) =
    Store { config | autoIncrement = True }



-- SCHEMA


{-| A database schema: name, version, and a list of store definitions.
-}
type Schema
    = Schema
        { name : String
        , version : Int
        , stores : List StoreConfig
        }


type alias StoreConfig =
    { name : String
    , keyPath : Maybe String
    , autoIncrement : Bool
    }


{-| Start building a schema with a database name and version number.

    mySchema : Schema
    mySchema =
        schema "myapp" 1
            |> withStore todosStore
            |> withStore cacheStore

-}
schema : String -> Int -> Schema
schema name version =
    Schema { name = name, version = version, stores = [] }


{-| Add a store to the schema. The phantom type is erased—stores of any key
configuration can be added to the same schema.
-}
withStore : Store k -> Schema -> Schema
withStore (Store config) (Schema s) =
    Schema { s | stores = s.stores ++ [ config ] }



-- DATABASE


{-| An opaque handle to an opened database. Must be threaded to all operations.
-}
type Db
    = Db String


{-| Open a database with the given schema. Creates or upgrades the database
as needed (adding new stores, removing stores not in the schema).

    open mySchema

-}
open : Schema -> ConcurrentTask Error Db
open (Schema s) =
    ConcurrentTask.define
        { function = "indexeddb:open"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args = encodeSchema (Schema s)
        }
        |> ConcurrentTask.map (\() -> Db s.name)


{-| Delete a database. Closes the connection first.
-}
deleteDatabase : Db -> ConcurrentTask Error ()
deleteDatabase db =
    ConcurrentTask.define
        { function = "indexeddb:deleteDatabase"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args = Encode.object [ ( "db", Encode.string (getDbName db) ) ]
        }



-- KEY


{-| A key for IndexedDB records. Constructors are exposed directly.

    StringKey "user-1"

    IntKey 42

    CompoundKey [ StringKey "2024", IntKey 1 ]

-}
type Key
    = StringKey String
    | IntKey Int
    | FloatKey Float
    | CompoundKey (List Key)



-- ERROR


{-| Errors that can occur during IndexedDB operations.

  - `AlreadyExists` — Attempted to `add` a record with an existing key.
  - `TransactionError` — The transaction failed (e.g. was aborted).
  - `QuotaExceeded` — Storage quota exceeded.
  - `DatabaseError` — Any other database error (schema mismatch, not open, etc).

-}
type Error
    = AlreadyExists
    | TransactionError String
    | QuotaExceeded
    | DatabaseError String



-- READ OPERATIONS


{-| Get a single record by key. Returns `Nothing` if the key doesn't exist.
-}
get : Db -> Store k -> Key -> Decoder a -> ConcurrentTask Error (Maybe a)
get db store key decoder =
    ConcurrentTask.define
        { function = "indexeddb:get"
        , expect = ConcurrentTask.expectJson (Decode.nullable decoder)
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                , ( "key", encodeKey key )
                ]
        }


{-| Get all records in a store.
-}
getAll : Db -> Store k -> Decoder a -> ConcurrentTask Error (List a)
getAll db store decoder =
    ConcurrentTask.define
        { function = "indexeddb:getAll"
        , expect = ConcurrentTask.expectJson (Decode.list decoder)
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                ]
        }


{-| Get all primary keys in a store.
-}
getAllKeys : Db -> Store k -> ConcurrentTask Error (List Key)
getAllKeys db store =
    ConcurrentTask.define
        { function = "indexeddb:getAllKeys"
        , expect = ConcurrentTask.expectJson (Decode.list keyDecoder)
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                ]
        }


{-| Count the number of records in a store.
-}
count : Db -> Store k -> ConcurrentTask Error Int
count db store =
    ConcurrentTask.define
        { function = "indexeddb:count"
        , expect = ConcurrentTask.expectJson Decode.int
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                ]
        }



-- WRITE OPERATIONS: InlineKey


{-| Upsert a value into an InlineKey store. The key is extracted from the
value at the store's keyPath. Returns the key.
-}
put : Db -> Store InlineKey -> Value -> ConcurrentTask Error Key
put db store value =
    ConcurrentTask.define
        { function = "indexeddb:put"
        , expect = ConcurrentTask.expectJson keyDecoder
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                , ( "value", value )
                ]
        }


{-| Insert a value into an InlineKey store. Fails with `AlreadyExists` if
the key (extracted from the value) already exists. Returns the key.
-}
add : Db -> Store InlineKey -> Value -> ConcurrentTask Error Key
add db store value =
    ConcurrentTask.define
        { function = "indexeddb:add"
        , expect = ConcurrentTask.expectJson keyDecoder
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                , ( "value", value )
                ]
        }



-- WRITE OPERATIONS: ExplicitKey


{-| Upsert a value at the given key in an ExplicitKey store.
-}
putAt : Db -> Store ExplicitKey -> Key -> Value -> ConcurrentTask Error ()
putAt db store key value =
    ConcurrentTask.define
        { function = "indexeddb:put"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                , ( "key", encodeKey key )
                , ( "value", value )
                ]
        }


{-| Insert a value at the given key in an ExplicitKey store. Fails with
`AlreadyExists` if the key already exists.
-}
addAt : Db -> Store ExplicitKey -> Key -> Value -> ConcurrentTask Error ()
addAt db store key value =
    ConcurrentTask.define
        { function = "indexeddb:add"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                , ( "key", encodeKey key )
                , ( "value", value )
                ]
        }



-- WRITE OPERATIONS: GeneratedKey


{-| Insert a value into a GeneratedKey store. The key is auto-generated.
Returns the generated key.
-}
insert : Db -> Store GeneratedKey -> Value -> ConcurrentTask Error Key
insert db store value =
    ConcurrentTask.define
        { function = "indexeddb:put"
        , expect = ConcurrentTask.expectJson keyDecoder
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                , ( "value", value )
                ]
        }



-- DELETE OPERATIONS


{-| Delete a record by key.
-}
delete : Db -> Store k -> Key -> ConcurrentTask Error ()
delete db store key =
    ConcurrentTask.define
        { function = "indexeddb:delete"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                , ( "key", encodeKey key )
                ]
        }


{-| Delete all records in a store.
-}
clear : Db -> Store k -> ConcurrentTask Error ()
clear db store =
    ConcurrentTask.define
        { function = "indexeddb:clear"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                ]
        }



-- BATCH OPERATIONS


{-| Put many values into an InlineKey store in a single transaction.
-}
putMany : Db -> Store InlineKey -> List Value -> ConcurrentTask Error ()
putMany db store values =
    ConcurrentTask.define
        { function = "indexeddb:putMany"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                , ( "entries", Encode.list (\v -> Encode.object [ ( "value", v ) ]) values )
                ]
        }


{-| Put many key-value pairs into an ExplicitKey store in a single transaction.
-}
putManyAt : Db -> Store ExplicitKey -> List ( Key, Value ) -> ConcurrentTask Error ()
putManyAt db store pairs =
    ConcurrentTask.define
        { function = "indexeddb:putMany"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                , ( "entries"
                  , Encode.list
                        (\( k, v ) ->
                            Encode.object
                                [ ( "key", encodeKey k )
                                , ( "value", v )
                                ]
                        )
                        pairs
                  )
                ]
        }


{-| Insert many values into a GeneratedKey store in a single transaction.
-}
insertMany : Db -> Store GeneratedKey -> List Value -> ConcurrentTask Error ()
insertMany db store values =
    ConcurrentTask.define
        { function = "indexeddb:insertMany"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                , ( "values", Encode.list identity values )
                ]
        }


{-| Delete many records by key in a single transaction.
-}
deleteMany : Db -> Store k -> List Key -> ConcurrentTask Error ()
deleteMany db store keys =
    ConcurrentTask.define
        { function = "indexeddb:deleteMany"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args =
            Encode.object
                [ ( "db", Encode.string (getDbName db) )
                , ( "store", Encode.string (getStoreName store) )
                , ( "keys", Encode.list encodeKey keys )
                ]
        }



-- INTERNAL: Encoders / Decoders


getDbName : Db -> String
getDbName (Db name) =
    name


getStoreName : Store k -> String
getStoreName (Store config) =
    config.name


encodeKey : Key -> Value
encodeKey key =
    case key of
        StringKey s ->
            Encode.object
                [ ( "type", Encode.string "string" )
                , ( "value", Encode.string s )
                ]

        IntKey i ->
            Encode.object
                [ ( "type", Encode.string "int" )
                , ( "value", Encode.int i )
                ]

        FloatKey f ->
            Encode.object
                [ ( "type", Encode.string "float" )
                , ( "value", Encode.float f )
                ]

        CompoundKey keys ->
            Encode.object
                [ ( "type", Encode.string "compound" )
                , ( "value", Encode.list encodeKey keys )
                ]


keyDecoder : Decoder Key
keyDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\t ->
                case t of
                    "string" ->
                        Decode.map StringKey (Decode.field "value" Decode.string)

                    "int" ->
                        Decode.map IntKey (Decode.field "value" Decode.int)

                    "float" ->
                        Decode.map FloatKey (Decode.field "value" Decode.float)

                    "compound" ->
                        Decode.map CompoundKey
                            (Decode.field "value"
                                (Decode.list (Decode.lazy (\_ -> keyDecoder)))
                            )

                    _ ->
                        Decode.fail ("Unknown key type: " ++ t)
            )


encodeSchema : Schema -> Value
encodeSchema (Schema s) =
    Encode.object
        [ ( "name", Encode.string s.name )
        , ( "version", Encode.int s.version )
        , ( "stores", Encode.list encodeStoreConfig s.stores )
        ]


encodeStoreConfig : StoreConfig -> Value
encodeStoreConfig config =
    Encode.object
        [ ( "name", Encode.string config.name )
        , ( "keyPath"
          , case config.keyPath of
                Just p ->
                    Encode.string p

                Nothing ->
                    Encode.null
          )
        , ( "autoIncrement", Encode.bool config.autoIncrement )
        ]


errorDecoder : Decoder Error
errorDecoder =
    Decode.string
        |> Decode.andThen
            (\err ->
                if err == "ALREADY_EXISTS" then
                    Decode.succeed AlreadyExists

                else if err == "QUOTA_EXCEEDED" then
                    Decode.succeed QuotaExceeded

                else
                    case splitOnce ":" err of
                        Just ( "TRANSACTION_ERROR", msg ) ->
                            Decode.succeed (TransactionError msg)

                        Just ( "DATABASE_ERROR", msg ) ->
                            Decode.succeed (DatabaseError msg)

                        _ ->
                            Decode.fail ("Unknown IndexedDB error: " ++ err)
            )


splitOnce : String -> String -> Maybe ( String, String )
splitOnce sep str =
    case String.indexes sep str of
        i :: _ ->
            Just
                ( String.left i str
                , String.dropLeft (i + String.length sep) str
                )

        [] ->
            Nothing
