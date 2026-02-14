-module(pets_api_SUITE).

-compile({no_auto_import, [get/1, put/2]}).

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
    list_empty/1,
    create_pet/1,
    create_pet_missing_required/1,
    show_pet/1,
    show_pet_not_found/1,
    update_pet/1,
    update_pet_not_found/1,
    delete_pet/1,
    delete_pet_not_found/1,
    full_crud_lifecycle/1
]).

%%--------------------------------------------------------------------
%% Suite setup
%%--------------------------------------------------------------------

all() ->
    [
        list_empty,
        create_pet,
        create_pet_missing_required,
        show_pet,
        show_pet_not_found,
        update_pet,
        update_pet_not_found,
        delete_pet,
        delete_pet_not_found,
        full_crud_lifecycle
    ].

init_per_suite(Config) ->
    application:ensure_all_started(inets),
    {ok, _} = application:ensure_all_started(pet_store),
    Config.

end_per_suite(_Config) ->
    application:stop(pet_store),
    ok.

init_per_testcase(_TC, Config) ->
    cleanup_pets(),
    Config.

end_per_testcase(_TC, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% Tests
%%--------------------------------------------------------------------

list_empty(_Config) ->
    {200, Body} = get("/api/pets"),
    ?assertMatch(#{<<"data">> := []}, Body).

create_pet(_Config) ->
    Params = #{
        <<"name">> => <<"Luna">>,
        <<"species">> => <<"cat">>,
        <<"breed">> => <<"Siamese">>,
        <<"age">> => 3,
        <<"weight">> => 4.5
    },
    {201, Body} = post("/api/pets", Params),
    Pet = maps:get(<<"data">>, Body),
    ?assertEqual(<<"Luna">>, maps:get(<<"name">>, Pet)),
    ?assertEqual(<<"cat">>, maps:get(<<"species">>, Pet)),
    ?assertEqual(<<"Siamese">>, maps:get(<<"breed">>, Pet)),
    ?assertEqual(3, maps:get(<<"age">>, Pet)),
    ?assert(is_integer(maps:get(<<"id">>, Pet))),
    ?assertNotEqual(null, maps:get(<<"inserted_at">>, Pet)),
    ?assertNotEqual(null, maps:get(<<"updated_at">>, Pet)).

create_pet_missing_required(_Config) ->
    Params = #{<<"breed">> => <<"Siamese">>},
    {422, Body} = post("/api/pets", Params),
    Errors = maps:get(<<"errors">>, Body),
    ?assert(maps:is_key(<<"name">>, Errors)),
    ?assert(maps:is_key(<<"species">>, Errors)).

show_pet(_Config) ->
    {201, Created} = post("/api/pets", #{<<"name">> => <<"Rex">>, <<"species">> => <<"dog">>}),
    Id = maps:get(<<"id">>, maps:get(<<"data">>, Created)),
    {200, Body} = get("/api/pets/" ++ integer_to_list(Id)),
    Pet = maps:get(<<"data">>, Body),
    ?assertEqual(<<"Rex">>, maps:get(<<"name">>, Pet)),
    ?assertEqual(Id, maps:get(<<"id">>, Pet)).

show_pet_not_found(_Config) ->
    {404, Body} = get("/api/pets/999999"),
    ?assertMatch(#{<<"error">> := <<"Pet not found">>}, Body).

update_pet(_Config) ->
    {201, Created} = post("/api/pets", #{<<"name">> => <<"Buddy">>, <<"species">> => <<"dog">>}),
    Id = maps:get(<<"id">>, maps:get(<<"data">>, Created)),
    {200, Body} = put("/api/pets/" ++ integer_to_list(Id), #{
        <<"name">> => <<"Buddy Updated">>, <<"age">> => 5
    }),
    Pet = maps:get(<<"data">>, Body),
    ?assertEqual(<<"Buddy Updated">>, maps:get(<<"name">>, Pet)),
    ?assertEqual(5, maps:get(<<"age">>, Pet)),
    ?assertEqual(Id, maps:get(<<"id">>, Pet)).

update_pet_not_found(_Config) ->
    {404, Body} = put("/api/pets/999999", #{<<"name">> => <<"Ghost">>}),
    ?assertMatch(#{<<"error">> := <<"Pet not found">>}, Body).

delete_pet(_Config) ->
    {201, Created} = post("/api/pets", #{<<"name">> => <<"Temp">>, <<"species">> => <<"fish">>}),
    Id = maps:get(<<"id">>, maps:get(<<"data">>, Created)),
    {204, _} = delete("/api/pets/" ++ integer_to_list(Id)),
    {404, _} = get("/api/pets/" ++ integer_to_list(Id)).

delete_pet_not_found(_Config) ->
    {404, Body} = delete("/api/pets/999999"),
    ?assertMatch(#{<<"error">> := <<"Pet not found">>}, Body).

full_crud_lifecycle(_Config) ->
    %% Create
    {201, C1} = post("/api/pets", #{
        <<"name">> => <<"Milo">>,
        <<"species">> => <<"cat">>,
        <<"breed">> => <<"Tabby">>,
        <<"age">> => 2,
        <<"weight">> => 3.8
    }),
    Id = maps:get(<<"id">>, maps:get(<<"data">>, C1)),

    %% List contains the pet
    {200, L1} = get("/api/pets"),
    ?assertEqual(1, length(maps:get(<<"data">>, L1))),

    %% Show
    {200, S1} = get("/api/pets/" ++ integer_to_list(Id)),
    ?assertEqual(<<"Milo">>, maps:get(<<"name">>, maps:get(<<"data">>, S1))),

    %% Update
    {200, U1} = put("/api/pets/" ++ integer_to_list(Id), #{
        <<"name">> => <<"Milo Senior">>, <<"age">> => 10
    }),
    ?assertEqual(<<"Milo Senior">>, maps:get(<<"name">>, maps:get(<<"data">>, U1))),
    ?assertEqual(10, maps:get(<<"age">>, maps:get(<<"data">>, U1))),

    %% Delete
    {204, _} = delete("/api/pets/" ++ integer_to_list(Id)),

    %% List is empty again
    {200, L2} = get("/api/pets"),
    ?assertEqual([], maps:get(<<"data">>, L2)).

%%--------------------------------------------------------------------
%% HTTP helpers
%%--------------------------------------------------------------------

base_url() ->
    "http://localhost:8085".

get(Path) ->
    URL = base_url() ++ Path,
    {ok, {{_, Status, _}, _Headers, RespBody}} =
        httpc:request(get, {URL, []}, [], [{body_format, binary}]),
    {Status, decode_body(Status, RespBody)}.

post(Path, Body) ->
    URL = base_url() ++ Path,
    JSON = thoas:encode(Body),
    {ok, {{_, Status, _}, _Headers, RespBody}} =
        httpc:request(post, {URL, [], "application/json", JSON}, [], [{body_format, binary}]),
    {Status, decode_body(Status, RespBody)}.

put(Path, Body) ->
    URL = base_url() ++ Path,
    JSON = thoas:encode(Body),
    {ok, {{_, Status, _}, _Headers, RespBody}} =
        httpc:request(put, {URL, [], "application/json", JSON}, [], [{body_format, binary}]),
    {Status, decode_body(Status, RespBody)}.

delete(Path) ->
    URL = base_url() ++ Path,
    {ok, {{_, Status, _}, _Headers, RespBody}} =
        httpc:request(delete, {URL, []}, [], [{body_format, binary}]),
    {Status, decode_body(Status, RespBody)}.

decode_body(204, _) ->
    #{};
decode_body(_, <<>>) ->
    #{};
decode_body(_, Body) ->
    {ok, Decoded} = thoas:decode(Body),
    Decoded.

%%--------------------------------------------------------------------
%% DB cleanup
%%--------------------------------------------------------------------

cleanup_pets() ->
    pet_store_repo:query(<<"TRUNCATE TABLE pets RESTART IDENTITY CASCADE">>, []).
