-module(pet_store_session_controller).

-export([create/1, delete/1]).

-define(COOKIE_NAME, <<"session_token">>).
-define(COOKIE_OPTS, #{path => <<"/">>, http_only => true, max_age => 14 * 24 * 60 * 60}).

create(Req) ->
    #{<<"email">> := Email, <<"password">> := Password} = maps:get(json, Req),
    case pet_store_accounts:get_user_by_email_and_password(Email, Password) of
        {ok, User} ->
            {ok, Token} = pet_store_accounts:generate_session_token(User),
            Req1 = cowboy_req:set_resp_cookie(?COOKIE_NAME, Token, Req, ?COOKIE_OPTS),
            {json, 200, #{}, Req1, #{<<"user">> => pet_store_accounts:user_to_json(User)}};
        {error, _} ->
            {json, 401, #{}, #{<<"error">> => <<"invalid email or password">>}}
    end.

delete(Req) ->
    case get_session_token(Req) of
        {ok, Token} ->
            pet_store_accounts:delete_session_token(Token);
        _ ->
            ok
    end,
    Req1 = cowboy_req:set_resp_cookie(?COOKIE_NAME, <<>>, Req, #{path => <<"/">>, max_age => 0}),
    {status, 204, #{}, <<>>, Req1}.

%%----------------------------------------------------------------------
%% Internal
%%----------------------------------------------------------------------

get_session_token(Req) ->
    #{session_token := Token} = cowboy_req:match_cookies([{session_token, [], undefined}], Req),
    case Token of
        undefined -> {error, not_found};
        _ -> {ok, Token}
    end.
