-module(pet_store_auth_page_SUITE).

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
    register_valid/1,
    register_invalid/1,
    login_valid/1,
    login_invalid/1,
    logout/1,
    create_pet_logged_in/1,
    create_pet_not_logged_in/1
]).

-define(BASE_URL, "http://localhost:8085").

all() ->
    [
        register_valid,
        register_invalid,
        login_valid,
        login_invalid,
        logout,
        create_pet_logged_in,
        create_pet_not_logged_in
    ].

init_per_suite(Config) ->
    application:ensure_all_started(inets),
    case application:ensure_all_started(pet_store) of
        {ok, _} ->
            ok;
        {error, {pet_store, {bad_return, _}}} ->
            %% App already running from previous suite
            ok
    end,
    Config.

end_per_suite(_Config) ->
    application:stop(pet_store),
    ok.

init_per_testcase(_TC, Config) ->
    cleanup(),
    Config.

end_per_testcase(_TC, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% Tests
%%--------------------------------------------------------------------

register_valid(_Config) ->
    FormBody =
        "email=reg%40example.com&password=password123456&password_confirmation=password123456",
    {ok, {{_, Status, _}, Headers, _}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/register", [], "application/x-www-form-urlencoded", FormBody},
            [{autoredirect, false}],
            [{body_format, binary}]
        ),
    ?assertEqual(302, Status),
    Location = proplists:get_value("location", Headers),
    ?assertEqual("/pets", Location).

register_invalid(_Config) ->
    FormBody = "email=bad&password=short&password_confirmation=nope",
    {ok, {{_, Status, _}, _, Body}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/register", [], "application/x-www-form-urlencoded", FormBody},
            [{autoredirect, false}],
            [{body_format, binary}]
        ),
    ?assertEqual(200, Status),
    ?assertNotEqual(nomatch, binary:match(Body, <<"Register">>)).

login_valid(_Config) ->
    register_user(),
    FormBody = "email=test%40example.com&password=password123456",
    {ok, {{_, Status, _}, Headers, _}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/login", [], "application/x-www-form-urlencoded", FormBody},
            [{autoredirect, false}],
            [{body_format, binary}]
        ),
    ?assertEqual(302, Status),
    Location = proplists:get_value("location", Headers),
    ?assertEqual("/pets", Location).

login_invalid(_Config) ->
    FormBody = "email=nobody%40example.com&password=wrongpassword1",
    {ok, {{_, Status, _}, _, Body}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/login", [], "application/x-www-form-urlencoded", FormBody},
            [{autoredirect, false}],
            [{body_format, binary}]
        ),
    ?assertEqual(200, Status),
    ?assertNotEqual(nomatch, binary:match(Body, <<"Invalid email or password">>)).

logout(_Config) ->
    Cookie = register_and_get_cookie(),
    {ok, {{_, Status, _}, Headers, _}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/logout", [{"Cookie", Cookie}], "application/x-www-form-urlencoded", ""},
            [{autoredirect, false}],
            [{body_format, binary}]
        ),
    ?assertEqual(302, Status),
    Location = proplists:get_value("location", Headers),
    ?assertEqual("/pets", Location).

create_pet_logged_in(_Config) ->
    Cookie = register_and_get_cookie(),
    FormBody = "name=Luna&species=cat",
    {ok, {{_, Status, _}, Headers, _}} =
        httpc:request(
            post,
            {
                ?BASE_URL ++ "/pets/create",
                [{"Cookie", Cookie}],
                "application/x-www-form-urlencoded",
                FormBody
            },
            [{autoredirect, false}],
            [{body_format, binary}]
        ),
    ?assertEqual(302, Status),
    Location = proplists:get_value("location", Headers),
    ?assertEqual("/pets", Location).

create_pet_not_logged_in(_Config) ->
    FormBody = "name=Luna&species=cat",
    {ok, {{_, Status, _}, Headers, _}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/pets/create", [], "application/x-www-form-urlencoded", FormBody},
            [{autoredirect, false}],
            [{body_format, binary}]
        ),
    ?assertEqual(302, Status),
    Location = proplists:get_value("location", Headers),
    ?assertEqual("/login", Location).

%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------

register_user() ->
    FormBody =
        "email=test%40example.com&password=password123456&password_confirmation=password123456",
    {ok, {{_, 302, _}, _, _}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/register", [], "application/x-www-form-urlencoded", FormBody},
            [{autoredirect, false}],
            [{body_format, binary}]
        ).

register_and_get_cookie() ->
    FormBody =
        "email=test%40example.com&password=password123456&password_confirmation=password123456",
    {ok, {{_, 302, _}, Headers, _}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/register", [], "application/x-www-form-urlencoded", FormBody},
            [{autoredirect, false}],
            [{body_format, binary}]
        ),
    extract_cookies(Headers).

extract_cookies(Headers) ->
    Cookies = [V || {"set-cookie", V} <- Headers],
    string:join(
        [hd(string:tokens(C, ";")) || C <- Cookies],
        "; "
    ).

cleanup() ->
    pet_store_repo:query(<<"TRUNCATE TABLE user_tokens RESTART IDENTITY CASCADE">>, []),
    pet_store_repo:query(<<"TRUNCATE TABLE users RESTART IDENTITY CASCADE">>, []),
    pet_store_repo:query(<<"TRUNCATE TABLE pets RESTART IDENTITY CASCADE">>, []).
