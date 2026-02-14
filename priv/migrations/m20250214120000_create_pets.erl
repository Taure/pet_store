-module(m20250214120000_create_pets).
-behaviour(kura_migration).

-include_lib("kura/include/kura.hrl").

-export([up/0, down/0]).

up() ->
    [
        {create_table, <<"pets">>, [
            #kura_column{name = id, type = id, primary_key = true, nullable = false},
            #kura_column{name = name, type = string, nullable = false},
            #kura_column{name = species, type = string, nullable = false},
            #kura_column{name = breed, type = string},
            #kura_column{name = age, type = integer},
            #kura_column{name = weight, type = float},
            #kura_column{name = inserted_at, type = utc_datetime},
            #kura_column{name = updated_at, type = utc_datetime}
        ]}
    ].

down() ->
    [
        {drop_table, <<"pets">>}
    ].
