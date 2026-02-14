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
    %% Re-run migrations so subsequent suites have a clean schema
    reset_database(),
    kura_migrator:migrate(pet_store_repo),
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
    %% Migrate should create the pets table
    {ok, Applied} = kura_migrator:migrate(pet_store_repo),
    ?assert(lists:member(20250214120000, Applied)),

    %% Verify table exists with expected columns
    Columns = get_columns(<<"pets">>),
    ExpectedCols = [
        <<"id">>,
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

    %% Verify column types
    ?assertEqual(<<"bigint">>, get_column_type(<<"pets">>, <<"id">>)),
    ?assertEqual(<<"character varying">>, get_column_type(<<"pets">>, <<"name">>)),
    ?assertEqual(<<"integer">>, get_column_type(<<"pets">>, <<"age">>)),
    ?assertEqual(<<"double precision">>, get_column_type(<<"pets">>, <<"weight">>)),
    ?assertMatch(<<"timestamp", _/binary>>, get_column_type(<<"pets">>, <<"inserted_at">>)),

    %% Verify NOT NULL constraints
    ?assertEqual(<<"NO">>, get_nullable(<<"pets">>, <<"id">>)),
    ?assertEqual(<<"NO">>, get_nullable(<<"pets">>, <<"name">>)),
    ?assertEqual(<<"YES">>, get_nullable(<<"pets">>, <<"breed">>)).

add_column_migration(_Config) ->
    %% Run all migrations
    {ok, _} = kura_migrator:migrate(pet_store_repo),

    %% Verify microchip_id column was added by second migration
    Columns = get_columns(<<"pets">>),
    ?assert(lists:member(<<"microchip_id">>, Columns)),
    ?assertEqual(<<"character varying">>, get_column_type(<<"pets">>, <<"microchip_id">>)),
    ?assertEqual(<<"YES">>, get_nullable(<<"pets">>, <<"microchip_id">>)).

alter_table_preserves_data(_Config) ->
    %% Run only the first migration (create_table)
    {ok, _} = kura_migrator:migrate(pet_store_repo),

    %% Insert a pet using raw SQL (before second migration adds microchip_id)
    pet_store_repo:query(
        <<
            "INSERT INTO pets (name, species, breed, age, weight, inserted_at, updated_at) "
            "VALUES ($1, $2, $3, $4, $5, now(), now())"
        >>,
        [<<"Bella">>, <<"dog">>, <<"Golden Retriever">>, 4, 28.5]
    ),

    %% Verify the pet exists
    {ok, [Pet1]} = pet_store_repo:query(<<"SELECT * FROM pets WHERE name = $1">>, [<<"Bella">>]),
    ?assertEqual(<<"dog">>, maps:get(species, Pet1)),
    ?assertEqual(4, maps:get(age, Pet1)),

    %% Now rollback to before create_table, re-run only first migration,
    %% then run the add_column migration separately
    %% Actually — simpler: just run migrate again which applies the second migration
    %% But we already ran migrate above which applied both. Let's reset differently.

    %% Reset and do it step by step: create table, insert data, then alter table
    reset_database(),
    kura_migrator:ensure_schema_migrations(pet_store_repo),

    %% Manually run just the first migration
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

    %% Run migrate — should apply remaining migrations
    {ok, Applied} = kura_migrator:migrate(pet_store_repo),
    ?assert(lists:member(20250214130000, Applied)),

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
    %% Run all migrations, then rollback to undo add_microchip migration
    {ok, _} = kura_migrator:migrate(pet_store_repo),
    %% Rollback until microchip_id is gone (may need multiple rollbacks
    %% if auto-generated migrations come after add_microchip)
    rollback_until_column_gone(<<"pets">>, <<"microchip_id">>),

    Columns = get_columns(<<"pets">>),
    ?assertNot(lists:member(<<"microchip_id">>, Columns)),

    %% But the pets table should still exist with original columns
    ?assert(lists:member(<<"name">>, Columns)),
    ?assert(lists:member(<<"species">>, Columns)).

rollback_create_table(_Config) ->
    %% Run all, rollback everything
    {ok, _} = kura_migrator:migrate(pet_store_repo),
    rollback_all(),

    %% The pets table should be gone
    ?assertNot(table_exists(<<"pets">>)).

migrate_is_idempotent(_Config) ->
    %% Running migrate twice should be safe
    {ok, First} = kura_migrator:migrate(pet_store_repo),
    ?assert(length(First) > 0),

    {ok, Second} = kura_migrator:migrate(pet_store_repo),
    ?assertEqual([], Second).

status_tracks_applied(_Config) ->
    %% Before migration, all should be pending
    StatusBefore = kura_migrator:status(pet_store_repo),
    ?assert(lists:all(fun({_, _, S}) -> S =:= pending end, StatusBefore)),

    %% After migration, all should be up
    {ok, _} = kura_migrator:migrate(pet_store_repo),
    StatusAfter = kura_migrator:status(pet_store_repo),
    ?assert(lists:all(fun({_, _, S}) -> S =:= up end, StatusAfter)),

    %% After one rollback, last should be pending
    {ok, _} = kura_migrator:rollback(pet_store_repo),
    StatusMixed = kura_migrator:status(pet_store_repo),
    {_, _, LastStatus} = lists:last(StatusMixed),
    ?assertEqual(pending, LastStatus),
    {_, _, FirstStatus} = hd(StatusMixed),
    ?assertEqual(up, FirstStatus).

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
%% Reset
%%--------------------------------------------------------------------

reset_database() ->
    pet_store_repo:query(<<"DROP TABLE IF EXISTS pets CASCADE">>, []),
    pet_store_repo:query(<<"DROP TABLE IF EXISTS schema_migrations CASCADE">>, []).

rollback_all() ->
    case kura_migrator:rollback(pet_store_repo) of
        {ok, []} -> ok;
        {ok, _} -> rollback_all();
        {error, _} -> ok
    end.

rollback_until_column_gone(Table, Column) ->
    case lists:member(Column, get_columns(Table)) of
        false ->
            ok;
        true ->
            {ok, _} = kura_migrator:rollback(pet_store_repo),
            rollback_until_column_gone(Table, Column)
    end.
