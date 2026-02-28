-module(pets_list_view).
-compile({parse_transform, arizona_parse_transform}).
-behaviour(arizona_view).

-export([mount/2, render/1]).

mount(MountArg, _Request) ->
    CurrentUser = maps:get(current_user, MountArg, undefined),
    {ok, Pets} = pet_store_repo:all(kura_query:from(pet)),
    arizona_view:new(?MODULE, #{
        id => ~"pets-list",
        pets => Pets,
        current_user => CurrentUser
    }, {pets_layout, render, inner_content, #{current_user => CurrentUser}}).

render(Bindings) ->
    Pets = arizona_template:get_binding(pets, Bindings),
    CurrentUser = arizona_template:get_binding(current_user, Bindings),
    arizona_template:from_html(~"""
    <h2>All Pets</h2>
    {arizona_template:render_slot(pet_table(Pets))}
    {arizona_template:render_slot(add_pet_form(CurrentUser))}
    """).

add_pet_form(undefined) ->
    arizona_template:from_html(~"""
    <p style="margin-top: 2rem; text-align: center; color: #6b7280;">
        <a href="/login">Log in</a> to add pets.
    </p>
    """);
add_pet_form(_User) ->
    arizona_template:from_html(~"""
    <form action="/pets/create" method="post">
        <h2>Add a Pet</h2>
        <div class="form-grid">
            <div>
                <label for="name">Name *</label>
                <input type="text" id="name" name="name" required>
            </div>
            <div>
                <label for="species">Species *</label>
                <input type="text" id="species" name="species" required>
            </div>
            <div>
                <label for="breed">Breed</label>
                <input type="text" id="breed" name="breed">
            </div>
            <div>
                <label for="age">Age</label>
                <input type="number" id="age" name="age" min="0">
            </div>
            <div>
                <label for="weight">Weight</label>
                <input type="number" id="weight" name="weight" min="0" step="0.1">
            </div>
        </div>
        <button type="submit">Add Pet</button>
    </form>
    """).

pet_table([]) ->
    arizona_template:from_html(~"""
    <p class="empty">No pets yet. Add one below!</p>
    """);
pet_table(Pets) ->
    arizona_template:from_html(~""""
    <table>
        <thead>
            <tr>
                <th>Name</th>
                <th>Species</th>
                <th>Breed</th>
                <th>Age</th>
                <th>Weight</th>
            </tr>
        </thead>
        <tbody>
            {arizona_template:render_list(fun(Pet) ->
                arizona_template:from_html(~"""
                <tr>
                    <td>{maps:get(name, Pet, ~"")}</td>
                    <td>{maps:get(species, Pet, ~"")}</td>
                    <td>{maps:get(breed, Pet, ~"")}</td>
                    <td>{format_integer(maps:get(age, Pet, undefined))}</td>
                    <td>{format_float(maps:get(weight, Pet, undefined))}</td>
                </tr>
                """)
            end, Pets)}
        </tbody>
    </table>
    """").

format_integer(undefined) -> ~"";
format_integer(N) -> integer_to_binary(N).

format_float(undefined) -> ~"";
format_float(F) -> float_to_binary(F, [{decimals, 1}]).
