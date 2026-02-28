-module(m20260228000000_add_user_id_to_pets).
-behaviour(kura_migration).
-include_lib("kura/include/kura.hrl").

-export([up/0, down/0]).

up() ->
    [{execute, <<"TRUNCATE TABLE pets RESTART IDENTITY CASCADE">>},
     {alter_table, <<"pets">>, [
         {add_column, #kura_column{name = user_id, type = integer, nullable = false}}
     ]},
     {execute, <<"ALTER TABLE pets ADD CONSTRAINT pets_user_id_fkey "
                 "FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE">>}].

down() ->
    [{execute, <<"ALTER TABLE pets DROP CONSTRAINT pets_user_id_fkey">>},
     {alter_table, <<"pets">>, [
         {drop_column, user_id}
     ]}].
