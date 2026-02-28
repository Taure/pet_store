-module(pet_store_user_controller).

-export([show/1, update_password/1, update_email/1]).

-define(COOKIE_NAME, <<"session_token">>).
-define(COOKIE_OPTS, #{path => <<"/">>, http_only => true, max_age => 14 * 24 * 60 * 60}).

show(Req) ->
    User = maps:get(auth_data, Req),
    {json, #{<<"user">> => pet_store_accounts:user_to_json(User)}}.

update_password(Req) ->
    User = maps:get(auth_data, Req),
    #{<<"current_password">> := CurrentPassword} = maps:get(json, Req),
    NewParams = maps:get(json, Req),
    case pet_store_accounts:change_user_password(User, CurrentPassword, NewParams) of
        {ok, UpdatedUser} ->
            {ok, Token} = pet_store_accounts:generate_session_token(UpdatedUser),
            Req1 = cowboy_req:set_resp_cookie(?COOKIE_NAME, Token, Req, ?COOKIE_OPTS),
            {json, 200, #{}, Req1, #{<<"user">> => pet_store_accounts:user_to_json(UpdatedUser)}};
        {error, invalid_password} ->
            {json, 401, #{}, #{<<"error">> => <<"invalid current password">>}};
        {error, CS} ->
            {json, 422, #{}, #{<<"errors">> => pet_store_accounts:format_errors(CS)}}
    end.

update_email(Req) ->
    User = maps:get(auth_data, Req),
    #{<<"current_password">> := CurrentPassword} = maps:get(json, Req),
    NewParams = maps:get(json, Req),
    case pet_store_accounts:change_user_email(User, CurrentPassword, NewParams) of
        {ok, UpdatedUser} ->
            {ok, Token} = pet_store_accounts:generate_session_token(UpdatedUser),
            Req1 = cowboy_req:set_resp_cookie(?COOKIE_NAME, Token, Req, ?COOKIE_OPTS),
            {json, 200, #{}, Req1, #{<<"user">> => pet_store_accounts:user_to_json(UpdatedUser)}};
        {error, invalid_password} ->
            {json, 401, #{}, #{<<"error">> => <<"invalid current password">>}};
        {error, CS} ->
            {json, 422, #{}, #{<<"errors">> => pet_store_accounts:format_errors(CS)}}
    end.
