-module(pet_store_accounts).
-include_lib("kura/include/kura.hrl").

-export([
    register_user/1,
    get_user_by_email_and_password/2,
    get_user_by_id/1,
    generate_session_token/1,
    get_user_by_session_token/1,
    delete_session_token/1,
    delete_all_user_tokens/1,
    change_user_password/3,
    change_user_email/3,
    user_to_json/1,
    format_errors/1
]).

-define(SESSION_VALIDITY_DAYS, 14).

%%----------------------------------------------------------------------
%% Registration
%%----------------------------------------------------------------------

register_user(Params) ->
    Now = calendar:universal_time(),
    CS = pet_store_user:registration_changeset(#{}, Params),
    CS1 = kura_changeset:put_change(CS, inserted_at, Now),
    CS2 = kura_changeset:put_change(CS1, updated_at, Now),
    pet_store_repo:insert(strip_virtual(CS2)).

%%----------------------------------------------------------------------
%% Authentication
%%----------------------------------------------------------------------

get_user_by_email_and_password(Email, Password) ->
    Q = kura_query:where(kura_query:from(pet_store_user), {email, Email}),
    case pet_store_repo:all(Q) of
        {ok, [User]} ->
            case verify_password(Password, maps:get(hashed_password, User)) of
                true -> {ok, User};
                false -> {error, invalid_credentials}
            end;
        _ ->
            dummy_verify(),
            {error, invalid_credentials}
    end.

get_user_by_id(Id) ->
    case pet_store_repo:get(pet_store_user, Id) of
        {ok, User} -> {ok, User};
        _ -> {error, not_found}
    end.

%%----------------------------------------------------------------------
%% Session tokens
%%----------------------------------------------------------------------

generate_session_token(User) ->
    Raw = crypto:strong_rand_bytes(32),
    SessionToken = base64:encode(Raw),
    HashedToken = base64:encode(crypto:hash(sha256, Raw)),
    Now = calendar:universal_time(),
    CS = kura_changeset:cast(
        pet_store_user_token,
        #{},
        #{
            user_id => maps:get(id, User),
            token => HashedToken,
            context => <<"session">>,
            inserted_at => Now
        },
        [user_id, token, context, inserted_at]
    ),
    case pet_store_repo:insert(CS) of
        {ok, _} -> {ok, SessionToken};
        {error, _} = Err -> Err
    end.

get_user_by_session_token(SessionToken) ->
    try
        Raw = base64:decode(SessionToken),
        HashedToken = base64:encode(crypto:hash(sha256, Raw)),
        Q = kura_query:where(
            kura_query:where(
                kura_query:from(pet_store_user_token),
                {token, HashedToken}
            ),
            {context, <<"session">>}
        ),
        case pet_store_repo:all(Q) of
            {ok, [Token]} ->
                case token_valid(maps:get(inserted_at, Token)) of
                    true -> get_user_by_id(maps:get(user_id, Token));
                    false -> {error, token_expired}
                end;
            _ ->
                {error, not_found}
        end
    catch
        _:_ -> {error, invalid_token}
    end.

delete_session_token(SessionToken) ->
    try
        Raw = base64:decode(SessionToken),
        HashedToken = base64:encode(crypto:hash(sha256, Raw)),
        Q = kura_query:where(
            kura_query:where(
                kura_query:from(pet_store_user_token),
                {token, HashedToken}
            ),
            {context, <<"session">>}
        ),
        _ = pet_store_repo:delete_all(Q),
        ok
    catch
        _:_ -> ok
    end.

delete_all_user_tokens(UserId) ->
    Q = kura_query:where(kura_query:from(pet_store_user_token), {user_id, UserId}),
    _ = pet_store_repo:delete_all(Q),
    ok.

%%----------------------------------------------------------------------
%% Password & email changes
%%----------------------------------------------------------------------

change_user_password(User, CurrentPassword, NewParams) ->
    case verify_password(CurrentPassword, maps:get(hashed_password, User)) of
        true ->
            Now = calendar:universal_time(),
            CS = pet_store_user:password_changeset(User, NewParams),
            CS1 = kura_changeset:put_change(CS, updated_at, Now),
            case pet_store_repo:update(strip_virtual(CS1)) of
                {ok, UpdatedUser} ->
                    delete_all_user_tokens(maps:get(id, User)),
                    {ok, UpdatedUser};
                {error, _} = Err ->
                    Err
            end;
        false ->
            {error, invalid_password}
    end.

change_user_email(User, CurrentPassword, NewParams) ->
    case verify_password(CurrentPassword, maps:get(hashed_password, User)) of
        true ->
            Now = calendar:universal_time(),
            CS = pet_store_user:email_changeset(User, NewParams),
            CS1 = kura_changeset:put_change(CS, updated_at, Now),
            case pet_store_repo:update(CS1) of
                {ok, UpdatedUser} ->
                    delete_all_user_tokens(maps:get(id, User)),
                    {ok, UpdatedUser};
                {error, _} = Err ->
                    Err
            end;
        false ->
            {error, invalid_password}
    end.

%%----------------------------------------------------------------------
%% JSON helpers
%%----------------------------------------------------------------------

user_to_json(User) ->
    #{
        <<"id">> => maps:get(id, User),
        <<"email">> => maps:get(email, User)
    }.

format_errors(#kura_changeset{errors = Errors}) ->
    maps:from_list([{atom_to_binary(F), M} || {F, M} <- Errors]).

%%----------------------------------------------------------------------
%% Internal
%%----------------------------------------------------------------------

%% Workaround for kura 1.3.0 bug: insert_record/update_record derive Fields
%% from changes (including virtual fields) but dump_changes strips them.
strip_virtual(CS = #kura_changeset{schema = SchemaMod, changes = Changes}) ->
    NonVirtual = kura_schema:non_virtual_fields(SchemaMod),
    CS#kura_changeset{changes = maps:with(NonVirtual, Changes)}.

verify_password(Password, HashedPassword) ->
    {ok, Hash} = bcrypt:hashpw(binary_to_list(Password), binary_to_list(HashedPassword)),
    crypto:hash_equals(list_to_binary(Hash), HashedPassword).

dummy_verify() ->
    {ok, Salt} = bcrypt:gen_salt(),
    _ = bcrypt:hashpw("dummy", Salt),
    false.

token_valid(InsertedAt) ->
    Now = calendar:datetime_to_gregorian_seconds(calendar:universal_time()),
    TokenTime = calendar:datetime_to_gregorian_seconds(InsertedAt),
    (Now - TokenTime) < (?SESSION_VALIDITY_DAYS * 24 * 60 * 60).
