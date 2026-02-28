-module(pets_page_controller).

-include_lib("kura/include/kura.hrl").

-export([index/1, create/1]).

index(Req) ->
    CurrentUser = pet_store_auth:get_current_user(Req),
    ArizonaReq = arizona_cowboy_request:new(Req),
    View = pets_list_view:mount(#{current_user => CurrentUser}, ArizonaReq),
    {Html, _View} = arizona_renderer:render_layout(View),
    {status, 200, #{<<"content-type">> => <<"text/html; charset=utf-8">>},
        iolist_to_binary(Html)}.

create(Req) ->
    case pet_store_auth:get_current_user(Req) of
        undefined ->
            {redirect, "/login"};
        _User ->
            {ok, FormData, _Req1} = cowboy_req:read_urlencoded_body(Req),
            Params = maps:from_list([{K, V} || {K, V} <- FormData]),
            CS = kura_changeset:cast(pet, #{}, Params, [name, species, breed, age, weight]),
            CS1 = kura_changeset:validate_required(CS, [name, species]),
            case pet_store_repo:insert(CS1) of
                {ok, _Pet} ->
                    {redirect, "/pets"};
                {error, #kura_changeset{}} ->
                    {redirect, "/pets"}
            end
    end.
