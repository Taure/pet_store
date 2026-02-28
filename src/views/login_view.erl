-module(login_view).
-compile({parse_transform, arizona_parse_transform}).
-behaviour(arizona_view).

-export([mount/2, render/1]).

mount(MountArg, _Request) ->
    Error = maps:get(error, MountArg, undefined),
    arizona_view:new(?MODULE, #{
        id => ~"login",
        error => Error
    }, {pets_layout, render, inner_content, #{}}).

render(Bindings) ->
    Error = arizona_template:get_binding(error, Bindings),
    arizona_template:from_html(~""""
    <h2>Log In</h2>
    {arizona_template:render_slot(error_message(Error))}
    <form action="/login" method="post">
        <div class="form-grid">
            <div>
                <label for="email">Email</label>
                <input type="email" id="email" name="email" required>
            </div>
            <div>
                <label for="password">Password</label>
                <input type="password" id="password" name="password" required>
            </div>
        </div>
        <button type="submit">Log In</button>
    </form>
    <p style="margin-top: 1rem;">Don't have an account? <a href="/register">Register</a></p>
    """").

error_message(undefined) ->
    arizona_template:from_html(~"");
error_message(Msg) ->
    arizona_template:from_html(~""""
    <div style="background: #fee2e2; color: #991b1b; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
        <p>{Msg}</p>
    </div>
    """").
