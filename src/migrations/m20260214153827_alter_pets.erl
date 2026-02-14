-module(m20260214153827_alter_pets).
-behaviour(kura_migration).
-include_lib("kura/include/kura.hrl").
-export([up/0, down/0]).

up() ->
    [{alter_table, <<"pets">>, [
        {add_column, #kura_column{name = color, type = string}}
    ]}].

down() ->
    [{alter_table, <<"pets">>, [
        {drop_column, color}
    ]}].
