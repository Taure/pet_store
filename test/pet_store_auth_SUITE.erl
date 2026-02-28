-module(pet_store_auth_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([
    all/0,
    init_per_suite/1,
    end_per_suite/1,
    init_per_testcase/2,
    end_per_testcase/2
]).
-export([
    test_register/1,
    test_register_invalid/1,
    test_login/1,
    test_login_invalid/1,
    test_logout/1,
    test_get_current_user/1,
    test_unauthorized/1,
    test_update_password/1,
    test_update_email/1
]).

-define(BASE_URL, "http://localhost:8085").

all() ->
    [
        test_register,
        test_register_invalid,
        test_login,
        test_login_invalid,
        test_logout,
        test_get_current_user,
        test_unauthorized,
        test_update_password,
        test_update_email
    ].

init_per_suite(Config) ->
    application:ensure_all_started(inets),
    application:ensure_all_started(ssl),
    case application:ensure_all_started(pet_store) of
        {ok, _} -> ok;
        {error, {pet_store, {bad_return, _}}} -> ok
    end,
    Config.

end_per_suite(_Config) ->
    application:stop(pet_store),
    ok.

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, _Config) ->
    cleanup(),
    ok.

%%----------------------------------------------------------------------
%% Registration
%%----------------------------------------------------------------------

test_register(_Config) ->
    Body = encode(#{
        <<"email">> => <<"register@example.com">>,
        <<"password">> => <<"password123456">>,
        <<"password_confirmation">> => <<"password123456">>
    }),
    {ok, {{_, 201, _}, _, RespBody}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/api/register", [], "application/json", Body},
            [],
            []
        ),
    #{<<"user">> := #{<<"id">> := _, <<"email">> := <<"register@example.com">>}} =
        decode(RespBody).

test_register_invalid(_Config) ->
    %% Missing password
    Body1 = encode(#{<<"email">> => <<"invalid@example.com">>}),
    {ok, {{_, 422, _}, _, _}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/api/register", [], "application/json", Body1},
            [],
            []
        ),
    %% Short password
    Body2 = encode(#{
        <<"email">> => <<"invalid@example.com">>,
        <<"password">> => <<"short">>,
        <<"password_confirmation">> => <<"short">>
    }),
    {ok, {{_, 422, _}, _, _}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/api/register", [], "application/json", Body2},
            [],
            []
        ).

%%----------------------------------------------------------------------
%% Login / Logout
%%----------------------------------------------------------------------

test_login(_Config) ->
    register_user(<<"login@example.com">>, <<"password123456">>),
    Body = encode(#{
        <<"email">> => <<"login@example.com">>,
        <<"password">> => <<"password123456">>
    }),
    {ok, {{_, 200, _}, _, RespBody}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/api/login", [], "application/json", Body},
            [],
            []
        ),
    #{<<"user">> := #{<<"email">> := <<"login@example.com">>}} =
        decode(RespBody).

test_login_invalid(_Config) ->
    Body = encode(#{
        <<"email">> => <<"nobody@example.com">>,
        <<"password">> => <<"wrongpassword1">>
    }),
    {ok, {{_, 401, _}, _, _}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/api/login", [], "application/json", Body},
            [],
            []
        ).

test_logout(_Config) ->
    Cookie = register_and_login(<<"logout@example.com">>, <<"password123456">>),
    {ok, {{_, 204, _}, _, _}} =
        httpc:request(
            delete,
            {?BASE_URL ++ "/api/logout", [{"Cookie", Cookie}]},
            [],
            []
        ).

%%----------------------------------------------------------------------
%% Current user
%%----------------------------------------------------------------------

test_get_current_user(_Config) ->
    Cookie = register_and_login(<<"me@example.com">>, <<"password123456">>),
    {ok, {{_, 200, _}, _, RespBody}} =
        httpc:request(
            get,
            {?BASE_URL ++ "/api/me", [{"Cookie", Cookie}]},
            [],
            []
        ),
    #{<<"user">> := #{<<"email">> := <<"me@example.com">>}} =
        decode(RespBody).

test_unauthorized(_Config) ->
    {ok, {{_, 401, _}, _, _}} =
        httpc:request(get, {?BASE_URL ++ "/api/me", []}, [], []).

%%----------------------------------------------------------------------
%% Password & email update
%%----------------------------------------------------------------------

test_update_password(_Config) ->
    Cookie = register_and_login(<<"pwchange@example.com">>, <<"password123456">>),
    Body = encode(#{
        <<"current_password">> => <<"password123456">>,
        <<"password">> => <<"newpassword12345">>,
        <<"password_confirmation">> => <<"newpassword12345">>
    }),
    {ok, {{_, 200, _}, _, _}} =
        httpc:request(
            put,
            {?BASE_URL ++ "/api/me/password", [{"Cookie", Cookie}], "application/json", Body},
            [],
            []
        ).

test_update_email(_Config) ->
    Cookie = register_and_login(<<"emailchange@example.com">>, <<"password123456">>),
    Body = encode(#{
        <<"current_password">> => <<"password123456">>,
        <<"email">> => <<"newemail@example.com">>
    }),
    {ok, {{_, 200, _}, _, _}} =
        httpc:request(
            put,
            {?BASE_URL ++ "/api/me/email", [{"Cookie", Cookie}], "application/json", Body},
            [],
            []
        ).

%%----------------------------------------------------------------------
%% Helpers
%%----------------------------------------------------------------------

register_user(Email, Password) ->
    Body = encode(#{
        <<"email">> => Email,
        <<"password">> => Password,
        <<"password_confirmation">> => Password
    }),
    {ok, {{_, 201, _}, _, _}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/api/register", [], "application/json", Body},
            [],
            []
        ).

register_and_login(Email, Password) ->
    Body = encode(#{
        <<"email">> => Email,
        <<"password">> => Password,
        <<"password_confirmation">> => Password
    }),
    {ok, {{_, 201, _}, Headers, _}} =
        httpc:request(
            post,
            {?BASE_URL ++ "/api/register", [], "application/json", Body},
            [],
            []
        ),
    extract_cookie(Headers).

extract_cookie(Headers) ->
    Cookies = [V || {"set-cookie", V} <- Headers],
    string:join(
        [hd(string:tokens(C, ";")) || C <- Cookies],
        "; "
    ).

cleanup() ->
    pet_store_repo:query(<<"TRUNCATE TABLE user_tokens RESTART IDENTITY CASCADE">>, []),
    pet_store_repo:query(<<"TRUNCATE TABLE users RESTART IDENTITY CASCADE">>, []).

encode(Map) ->
    binary_to_list(thoas:encode(Map)).

decode(Body) ->
    {ok, Json} = thoas:decode(list_to_binary(Body)),
    Json.
