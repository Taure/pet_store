-module(docs_api_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([
    all/0,
    init_per_suite/1,
    end_per_suite/1
]).

-export([
    docs_returns_html/1,
    openapi_json_returns_spec/1
]).

all() ->
    [
        docs_returns_html,
        openapi_json_returns_spec
    ].

init_per_suite(Config) ->
    application:ensure_all_started(inets),
    application:ensure_all_started(ssl),
    {ok, _} = application:ensure_all_started(pet_store),
    Config.

end_per_suite(_Config) ->
    application:stop(pet_store),
    ok.

%%--------------------------------------------------------------------
%% Tests
%%--------------------------------------------------------------------

docs_returns_html(_Config) ->
    {ok, {{_, 200, _}, Headers, Body}} =
        httpc:request(get, {base_url() ++ "/api/docs", []}, [], [{body_format, binary}]),
    ContentType = proplists:get_value("content-type", Headers),
    ?assert(lists:prefix("text/html", ContentType)),
    ?assertNotEqual(nomatch, binary:match(Body, <<"swagger-ui">>)).

openapi_json_returns_spec(_Config) ->
    {ok, {{_, 200, _}, _Headers, Body}} =
        httpc:request(get, {base_url() ++ "/api/docs/openapi.json", []}, [], [{body_format, binary}]),
    {ok, Decoded} = thoas:decode(Body),
    ?assertMatch(#{<<"openapi">> := <<"3.0.3">>}, Decoded),
    ?assert(maps:is_key(<<"paths">>, Decoded)).

%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------

base_url() ->
    "http://localhost:8085".
