-module(pet_store_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    pet_store_repo:start(),
    configure_migration_paths(),
    case kura_migrator:migrate(pet_store_repo) of
        {ok, Applied} ->
            logger:info("Kura migrations applied: ~p", [Applied]);
        {error, Reason} ->
            logger:error("Kura migration failed: ~p", [Reason])
    end,
    pet_store_sup:start_link().

configure_migration_paths() ->
    LibDir = code:lib_dir(pet_store),
    MigPath = filename:join(LibDir, "migrations"),
    application:set_env(kura, migration_paths, [list_to_binary(MigPath)]).

stop(_State) ->
    ok.
