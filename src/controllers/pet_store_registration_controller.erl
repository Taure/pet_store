-module(pet_store_registration_controller).

-export([create/1]).

-define(COOKIE_NAME, <<"session_token">>).
-define(COOKIE_OPTS, #{path => <<"/">>, http_only => true, max_age => 14 * 24 * 60 * 60}).

create(Req) ->
    Params = maps:get(json, Req),
    case pet_store_accounts:register_user(Params) of
        {ok, User} ->
            {ok, Token} = pet_store_accounts:generate_session_token(User),
            Req1 = cowboy_req:set_resp_cookie(?COOKIE_NAME, Token, Req, ?COOKIE_OPTS),
            {json, 201, #{}, Req1, #{<<"user">> => pet_store_accounts:user_to_json(User)}};
        {error, CS} ->
            {json, 422, #{}, #{<<"errors">> => pet_store_accounts:format_errors(CS)}}
    end.
