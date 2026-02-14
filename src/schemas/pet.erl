-module(pet).
-behaviour(kura_schema).

-include_lib("kura/include/kura.hrl").

-export([table/0, fields/0, primary_key/0]).

table() -> <<"pets">>.

primary_key() -> id.

fields() ->
    [
        #kura_field{name = id, type = id, primary_key = true, nullable = false},
        #kura_field{name = name, type = string, nullable = false},
        #kura_field{name = species, type = string, nullable = false},
        #kura_field{name = breed, type = string},
        #kura_field{name = age, type = integer},
        #kura_field{name = weight, type = float},
        #kura_field{name = inserted_at, type = utc_datetime},
        #kura_field{name = updated_at, type = utc_datetime}
    ].
