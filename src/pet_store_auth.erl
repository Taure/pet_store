-module(pet_store_auth).

-export([require_authenticated/1, get_current_user/1]).

require_authenticated(Req) ->
    case get_token(Req) of
        {ok, Token} ->
            case pet_store_accounts:get_user_by_session_token(Token) of
                {ok, User} ->
                    {true, User};
                _ ->
                    unauthorized()
            end;
        _ ->
            unauthorized()
    end.

get_current_user(Req) ->
    case get_token(Req) of
        {ok, Token} ->
            case pet_store_accounts:get_user_by_session_token(Token) of
                {ok, User} -> User;
                _ -> undefined
            end;
        _ ->
            undefined
    end.

unauthorized() ->
    Body = thoas:encode(#{<<"error">> => <<"unauthorized">>}),
    {false, 401, #{<<"content-type">> => <<"application/json">>}, Body}.

%%----------------------------------------------------------------------
%% Internal
%%----------------------------------------------------------------------

get_token(Req) ->
    #{session_token := Token} =
        cowboy_req:match_cookies([{session_token, [], undefined}], Req),
    case Token of
        undefined ->
            case nova_session:get(Req, <<"session_token">>) of
                {ok, _} = Ok -> Ok;
                _ -> {error, not_found}
            end;
        _ ->
            {ok, Token}
    end.
