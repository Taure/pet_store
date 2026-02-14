-module(pets_controller).

-include_lib("kura/include/kura.hrl").

-export([index/1, show/1, create/1, update/1, delete/1]).

index(_Req) ->
    Q = kura_query:from(pet),
    {ok, Pets} = pet_store_repo:all(Q),
    {json, #{data => [serialize(P) || P <- Pets]}}.

show(#{bindings := #{<<"id">> := IdBin}} = _Req) ->
    Id = binary_to_integer(IdBin),
    case pet_store_repo:get(pet, Id) of
        {ok, Pet} ->
            {json, #{data => serialize(Pet)}};
        {error, not_found} ->
            {status, 404, #{}, #{error => <<"Pet not found">>}}
    end.

create(#{json := Params} = _Req) ->
    CS = kura_changeset:cast(pet, #{}, Params, [name, species, breed, age, weight]),
    CS1 = kura_changeset:validate_required(CS, [name, species]),
    case pet_store_repo:insert(CS1) of
        {ok, Pet} ->
            {status, 201, #{}, #{data => serialize(Pet)}};
        {error, #kura_changeset{errors = Errors}} ->
            {status, 422, #{}, #{errors => format_errors(Errors)}}
    end.

update(#{bindings := #{<<"id">> := IdBin}, json := Params} = _Req) ->
    Id = binary_to_integer(IdBin),
    case pet_store_repo:get(pet, Id) of
        {ok, Existing} ->
            CS = kura_changeset:cast(pet, Existing, Params, [name, species, breed, age, weight]),
            case pet_store_repo:update(CS) of
                {ok, Updated} ->
                    {json, #{data => serialize(Updated)}};
                {error, #kura_changeset{errors = Errors}} ->
                    {status, 422, #{}, #{errors => format_errors(Errors)}}
            end;
        {error, not_found} ->
            {status, 404, #{}, #{error => <<"Pet not found">>}}
    end.

delete(#{bindings := #{<<"id">> := IdBin}} = _Req) ->
    Id = binary_to_integer(IdBin),
    case pet_store_repo:get(pet, Id) of
        {ok, Existing} ->
            CS = kura_changeset:cast(pet, Existing, #{}, []),
            {ok, _} = pet_store_repo:delete(CS),
            {status, 204};
        {error, not_found} ->
            {status, 404, #{}, #{error => <<"Pet not found">>}}
    end.

%% Internal

serialize(Pet) ->
    #{
        id => maps:get(id, Pet),
        name => maps:get(name, Pet),
        species => maps:get(species, Pet),
        breed => maps:get(breed, Pet, null),
        age => maps:get(age, Pet, null),
        weight => maps:get(weight, Pet, null),
        inserted_at => format_datetime(maps:get(inserted_at, Pet, undefined)),
        updated_at => format_datetime(maps:get(updated_at, Pet, undefined))
    }.

format_datetime(undefined) -> null;
format_datetime({{Y, Mo, D}, {H, Mi, S}}) ->
    iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
                                   [Y, Mo, D, H, Mi, S])).

format_errors(Errors) ->
    maps:from_list([{atom_to_binary(Field), Msg} || {Field, Msg} <- Errors]).
