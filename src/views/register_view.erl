-module(register_view).
-compile({parse_transform, arizona_parse_transform}).
-behaviour(arizona_view).

-export([mount/2, render/1]).

mount(MountArg, _Request) ->
    Errors = maps:get(errors, MountArg, #{}),
    arizona_view:new(?MODULE, #{
        id => ~"register",
        errors => Errors
    }, {pets_layout, render, inner_content, #{}}).

render(Bindings) ->
    Errors = arizona_template:get_binding(errors, Bindings),
    arizona_template:from_html(~""""
    <h2>Register</h2>
    {arizona_template:render_slot(error_messages(Errors))}
    <form action="/register" method="post">
        <div class="form-grid">
            <div>
                <label for="email">Email</label>
                <input type="email" id="email" name="email" required>
            </div>
            <div>
                <label for="password">Password</label>
                <input type="password" id="password" name="password" required minlength="8">
            </div>
            <div>
                <label for="password_confirmation">Confirm Password</label>
                <input type="password" id="password_confirmation" name="password_confirmation" required>
            </div>
        </div>
        <button type="submit">Register</button>
    </form>
    <p style="margin-top: 1rem;">Already have an account? <a href="/login">Log in</a></p>
    """").

error_messages(Errors) when map_size(Errors) =:= 0 ->
    arizona_template:from_html(~"");
error_messages(Errors) ->
    arizona_template:from_html(~""""
    <div style="background: #fee2e2; color: #991b1b; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
        {arizona_template:render_list(fun({_Field, Msg}) ->
            arizona_template:from_html(~"""
            <p>{Msg}</p>
            """)
        end, maps:to_list(Errors))}
    </div>
    """").
