-module(pet_store_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    pet_store_repo:start(),
    case kura_migrator:migrate(pet_store_repo) of
        {ok, Applied} ->
            logger:info("Kura migrations applied: ~p", [Applied]);
        {error, Reason} ->
            logger:error("Kura migration failed: ~p", [Reason])
    end,
    pet_store_sup:start_link().

stop(_State) ->
    ok.
