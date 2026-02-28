-module(migrations_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([
    all/0,
    init_per_suite/1,
    end_per_suite/1,
    init_per_testcase/2,
    end_per_testcase/2
]).

-export([
    create_table_migration/1,
    add_column_migration/1,
    alter_table_preserves_data/1,
    rollback_add_column/1,
    rollback_create_table/1,
    migrate_is_idempotent/1,
    status_tracks_applied/1
]).

%%--------------------------------------------------------------------
%% Suite setup
%%--------------------------------------------------------------------

all() ->
    [
        create_table_migration,
        add_column_migration,
        alter_table_preserves_data,
        rollback_add_column,
        rollback_create_table,
        migrate_is_idempotent,
        status_tracks_applied
    ].

init_per_suite(Config) ->
    application:ensure_all_started(pet_store),
    Config.

end_per_suite(_Config) ->
    reset_database(),
    restore_schema(),
    ok.

init_per_testcase(_TC, Config) ->
    reset_database(),
    Config.

end_per_testcase(_TC, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% Tests
%%--------------------------------------------------------------------

create_table_migration(_Config) ->
    {ok, Applied} = apply_all_migrations(),
    ?assert(lists:member(20250214120000, Applied)),

    Columns = get_columns(<<"pets">>),
    ExpectedCols = [
        <<"id">>,
        <<"user_id">>,
        <<"name">>,
        <<"species">>,
        <<"breed">>,
        <<"age">>,
        <<"weight">>,
        <<"inserted_at">>,
        <<"updated_at">>,
        <<"microchip_id">>,
        <<"color">>
    ],
    [?assert(lists:member(C, Columns)) || C <- ExpectedCols],

    ?assertEqual(<<"bigint">>, get_column_type(<<"pets">>, <<"id">>)),
    ?assertEqual(<<"character varying">>, get_column_type(<<"pets">>, <<"name">>)),
    ?assertEqual(<<"integer">>, get_column_type(<<"pets">>, <<"age">>)),
    ?assertEqual(<<"double precision">>, get_column_type(<<"pets">>, <<"weight">>)),
    ?assertMatch(<<"timestamp", _/binary>>, get_column_type(<<"pets">>, <<"inserted_at">>)),

    ?assertEqual(<<"NO">>, get_nullable(<<"pets">>, <<"id">>)),
    ?assertEqual(<<"NO">>, get_nullable(<<"pets">>, <<"name">>)),
    ?assertEqual(<<"YES">>, get_nullable(<<"pets">>, <<"breed">>)).

add_column_migration(_Config) ->
    {ok, _} = apply_all_migrations(),

    Columns = get_columns(<<"pets">>),
    ?assert(lists:member(<<"microchip_id">>, Columns)),
    ?assertEqual(<<"character varying">>, get_column_type(<<"pets">>, <<"microchip_id">>)),
    ?assertEqual(<<"YES">>, get_nullable(<<"pets">>, <<"microchip_id">>)).

alter_table_preserves_data(_Config) ->
    kura_migrator:ensure_schema_migrations(pet_store_repo),

    %% Manually run just the first migration (create_pets)
    SQL1 = kura_migrator:compile_operation(hd(m20250214120000_create_pets:up())),
    pet_store_repo:query(SQL1, []),
    pet_store_repo:query(
        <<"INSERT INTO schema_migrations (version) VALUES ($1)">>, [20250214120000]
    ),

    %% Insert a pet before the alter
    pet_store_repo:query(
        <<
            "INSERT INTO pets (name, species, breed, age, weight, inserted_at, updated_at) "
            "VALUES ($1, $2, $3, $4, $5, now(), now())"
        >>,
        [<<"Bella">>, <<"dog">>, <<"Golden Retriever">>, 4, 28.5]
    ),

    %% Verify no microchip_id column yet
    ColumnsBefore = get_columns(<<"pets">>),
    ?assertNot(lists:member(<<"microchip_id">>, ColumnsBefore)),

    %% Manually apply just the add_microchip migration
    [Op] = m20250214130000_add_microchip_to_pets:up(),
    SQL2 = kura_migrator:compile_operation(Op),
    pet_store_repo:query(SQL2, []),
    pet_store_repo:query(
        <<"INSERT INTO schema_migrations (version) VALUES ($1)">>, [20250214130000]
    ),

    %% Verify the new column exists
    ColumnsAfter = get_columns(<<"pets">>),
    ?assert(lists:member(<<"microchip_id">>, ColumnsAfter)),

    %% Verify Bella is still there with all her original data intact
    {ok, [Pet2]} = pet_store_repo:query(<<"SELECT * FROM pets WHERE name = $1">>, [<<"Bella">>]),
    ?assertEqual(<<"dog">>, maps:get(species, Pet2)),
    ?assertEqual(<<"Golden Retriever">>, maps:get(breed, Pet2)),
    ?assertEqual(4, maps:get(age, Pet2)),

    %% The new column should be null for existing rows
    ?assertEqual(null, maps:get(microchip_id, Pet2)).

rollback_add_column(_Config) ->
    {ok, _} = apply_all_migrations(),
    rollback_until_column_gone(<<"pets">>, <<"microchip_id">>),

    Columns = get_columns(<<"pets">>),
    ?assertNot(lists:member(<<"microchip_id">>, Columns)),

    %% But the pets table should still exist with original columns
    ?assert(lists:member(<<"name">>, Columns)),
    ?assert(lists:member(<<"species">>, Columns)).

rollback_create_table(_Config) ->
    {ok, _} = apply_all_migrations(),
    rollback_all(),

    %% The pets table should be gone
    ?assertNot(table_exists(<<"pets">>)).

migrate_is_idempotent(_Config) ->
    {ok, First} = apply_all_migrations(),
    ?assert(length(First) > 0),

    {ok, Second} = apply_all_migrations(),
    ?assertEqual([], Second).

status_tracks_applied(_Config) ->
    %% Before migration, all should be pending
    StatusBefore = kura_migrator:status(pet_store_repo),
    ?assert(lists:all(fun({_, _, S}) -> S =:= pending end, StatusBefore)),

    %% After migration, all should be up
    {ok, _} = apply_all_migrations(),
    StatusAfter = kura_migrator:status(pet_store_repo),
    ?assert(lists:all(fun({_, _, S}) -> S =:= up end, StatusAfter)),

    %% After one rollback, last should be pending
    rollback_one(),
    StatusMixed = kura_migrator:status(pet_store_repo),
    {_, _, LastStatus} = lists:last(StatusMixed),
    ?assertEqual(pending, LastStatus),
    {_, _, FirstStatus} = hd(StatusMixed),
    ?assertEqual(up, FirstStatus).

%%--------------------------------------------------------------------
%% Migration helpers (bypass pgo advisory lock bug)
%%--------------------------------------------------------------------

migration_modules() ->
    [
        {20250214120000, m20250214120000_create_pets},
        {20250214130000, m20250214130000_add_microchip_to_pets},
        {20260214153827, m20260214153827_alter_pets},
        {20260224213202, m20260224213202_create_auth_tables},
        {20260228000000, m20260228000000_add_user_id_to_pets}
    ].

apply_all_migrations() ->
    kura_migrator:ensure_schema_migrations(pet_store_repo),
    Applied = get_applied_versions(),
    Pending = [{V, M} || {V, M} <- migration_modules(), not lists:member(V, Applied)],
    lists:foreach(
        fun({Version, Module}) ->
            Ops = Module:up(),
            lists:foreach(
                fun(Op) ->
                    SQL = kura_migrator:compile_operation(Op),
                    pet_store_repo:query(SQL, [])
                end,
                Ops
            ),
            pet_store_repo:query(
                <<"INSERT INTO schema_migrations (version) VALUES ($1)">>, [Version]
            )
        end,
        Pending
    ),
    {ok, [V || {V, _} <- Pending]}.

rollback_one() ->
    Applied = get_applied_versions(),
    case Applied of
        [] ->
            {ok, []};
        _ ->
            Version = lists:max(Applied),
            {_, Module} = lists:keyfind(Version, 1, migration_modules()),
            Ops = Module:down(),
            lists:foreach(
                fun(Op) ->
                    SQL = kura_migrator:compile_operation(Op),
                    pet_store_repo:query(SQL, [])
                end,
                Ops
            ),
            pet_store_repo:query(
                <<"DELETE FROM schema_migrations WHERE version = $1">>, [Version]
            ),
            {ok, [Version]}
    end.

rollback_all() ->
    case rollback_one() of
        {ok, []} -> ok;
        {ok, _} -> rollback_all()
    end.

rollback_until_column_gone(Table, Column) ->
    case lists:member(Column, get_columns(Table)) of
        false ->
            ok;
        true ->
            {ok, _} = rollback_one(),
            rollback_until_column_gone(Table, Column)
    end.

get_applied_versions() ->
    case
        pet_store_repo:query(
            <<"SELECT version FROM schema_migrations ORDER BY version">>, []
        )
    of
        {ok, Rows} -> [maps:get(version, R) || R <- Rows];
        _ -> []
    end.

%%--------------------------------------------------------------------
%% DB introspection helpers
%%--------------------------------------------------------------------

get_columns(Table) ->
    SQL =
        <<"SELECT column_name FROM information_schema.columns WHERE table_name = $1 ORDER BY ordinal_position">>,
    case pet_store_repo:query(SQL, [Table]) of
        {ok, Rows} ->
            [maps:get(column_name, R) || R <- Rows];
        _ ->
            []
    end.

get_column_type(Table, Column) ->
    SQL =
        <<"SELECT data_type FROM information_schema.columns WHERE table_name = $1 AND column_name = $2">>,
    {ok, [Row]} = pet_store_repo:query(SQL, [Table, Column]),
    maps:get(data_type, Row).

get_nullable(Table, Column) ->
    SQL =
        <<"SELECT is_nullable FROM information_schema.columns WHERE table_name = $1 AND column_name = $2">>,
    {ok, [Row]} = pet_store_repo:query(SQL, [Table, Column]),
    maps:get(is_nullable, Row).

table_exists(Table) ->
    SQL = <<"SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = $1)">>,
    {ok, [Row]} = pet_store_repo:query(SQL, [Table]),
    maps:get(exists, Row).

%%--------------------------------------------------------------------
%% Reset / Restore
%%--------------------------------------------------------------------

reset_database() ->
    pet_store_repo:query(<<"DROP TABLE IF EXISTS pets CASCADE">>, []),
    pet_store_repo:query(<<"DROP TABLE IF EXISTS user_tokens CASCADE">>, []),
    pet_store_repo:query(<<"DROP TABLE IF EXISTS users CASCADE">>, []),
    pet_store_repo:query(<<"DROP TABLE IF EXISTS schema_migrations CASCADE">>, []).

restore_schema() ->
    {ok, _} = apply_all_migrations().
