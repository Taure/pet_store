-module(auth_page_controller).

-include_lib("kura/include/kura.hrl").

-export([register_page/1, register/1, login_page/1, login/1, logout/1]).

-define(COOKIE_NAME, <<"session_token">>).
-define(COOKIE_OPTS, #{path => <<"/">>, http_only => true, max_age => 14 * 24 * 60 * 60}).

register_page(Req) ->
    render_view(register_view, #{}, Req).

register(Req) ->
    {ok, FormData, _Req1} = cowboy_req:read_urlencoded_body(Req),
    Params = maps:from_list([{K, V} || {K, V} <- FormData]),
    case pet_store_accounts:register_user(Params) of
        {ok, User} ->
            {ok, Token} = pet_store_accounts:generate_session_token(User),
            Req1 = cowboy_req:set_resp_cookie(?COOKIE_NAME, Token, Req, ?COOKIE_OPTS),
            {redirect, "/pets", Req1};
        {error, #kura_changeset{} = CS} ->
            Errors = pet_store_accounts:format_errors(CS),
            render_view(register_view, #{errors => Errors}, Req)
    end.

login_page(Req) ->
    render_view(login_view, #{}, Req).

login(Req) ->
    {ok, FormData, _Req1} = cowboy_req:read_urlencoded_body(Req),
    Params = maps:from_list([{K, V} || {K, V} <- FormData]),
    Email = maps:get(<<"email">>, Params, <<>>),
    Password = maps:get(<<"password">>, Params, <<>>),
    case pet_store_accounts:get_user_by_email_and_password(Email, Password) of
        {ok, User} ->
            {ok, Token} = pet_store_accounts:generate_session_token(User),
            Req1 = cowboy_req:set_resp_cookie(?COOKIE_NAME, Token, Req, ?COOKIE_OPTS),
            {redirect, "/pets", Req1};
        {error, _} ->
            render_view(login_view, #{error => <<"Invalid email or password">>}, Req)
    end.

logout(Req) ->
    case get_session_token(Req) of
        {ok, Token} ->
            pet_store_accounts:delete_session_token(Token);
        _ ->
            ok
    end,
    Req1 = cowboy_req:set_resp_cookie(?COOKIE_NAME, <<>>, Req, #{path => <<"/">>, max_age => 0}),
    {redirect, "/pets", Req1}.

%%----------------------------------------------------------------------
%% Internal
%%----------------------------------------------------------------------

get_session_token(Req) ->
    #{session_token := Token} = cowboy_req:match_cookies([{session_token, [], undefined}], Req),
    case Token of
        undefined -> {error, not_found};
        _ -> {ok, Token}
    end.

render_view(ViewMod, MountArg, Req) ->
    ArizonaReq = arizona_cowboy_request:new(Req),
    View = ViewMod:mount(MountArg, ArizonaReq),
    {Html, _View} = arizona_renderer:render_layout(View),
    {status, 200, #{<<"content-type">> => <<"text/html; charset=utf-8">>},
        iolist_to_binary(Html)}.
