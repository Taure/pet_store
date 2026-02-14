-module(m20250214130000_add_microchip_to_pets).
-behaviour(kura_migration).

-include_lib("kura/include/kura.hrl").

-export([up/0, down/0]).

up() ->
    [
        {alter_table, <<"pets">>, [
            {add_column, #kura_column{name = microchip_id, type = string}}
        ]}
    ].

down() ->
    [
        {alter_table, <<"pets">>, [
            {drop_column, microchip_id}
        ]}
    ].
