-module(pets_layout).
-compile({parse_transform, arizona_parse_transform}).

-export([render/1]).

render(Bindings) ->
    CurrentUser = arizona_template:get_binding(current_user, Bindings, undefined),
    arizona_template:from_html(~""""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Pet Store</title>
        <style>
            * \{ box-sizing: border-box; margin: 0; padding: 0; }
            body \{ font-family: system-ui, -apple-system, sans-serif; background: #f5f5f5; color: #333; }
            nav \{ background: #2563eb; color: white; padding: 1rem 2rem; display: flex; justify-content: space-between; align-items: center; }
            nav h1 \{ font-size: 1.25rem; }
            nav .nav-links \{ display: flex; gap: 1rem; align-items: center; }
            nav a \{ color: white; text-decoration: none; }
            nav a:hover \{ text-decoration: underline; }
            nav .user-email \{ opacity: 0.9; font-size: 0.875rem; }
            main \{ max-width: 960px; margin: 2rem auto; padding: 0 1rem; }
            table \{ width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
            th, td \{ padding: 0.75rem 1rem; text-align: left; border-bottom: 1px solid #e5e7eb; }
            th \{ background: #f9fafb; font-weight: 600; }
            form \{ background: white; padding: 1.5rem; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); margin-top: 2rem; }
            form h2 \{ margin-bottom: 1rem; }
            .form-grid \{ display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 1rem; }
            label \{ display: block; font-weight: 500; margin-bottom: 0.25rem; font-size: 0.875rem; }
            input \{ width: 100%; padding: 0.5rem; border: 1px solid #d1d5db; border-radius: 4px; font-size: 0.875rem; }
            button \{ margin-top: 1rem; padding: 0.5rem 1.5rem; background: #2563eb; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 0.875rem; }
            button:hover \{ background: #1d4ed8; }
            .empty \{ text-align: center; padding: 2rem; color: #6b7280; }
            .logout-form \{ display: inline; margin: 0; padding: 0; background: none; box-shadow: none; }
            .logout-btn \{ background: none; color: white; border: none; cursor: pointer; font-size: 0.875rem; text-decoration: underline; padding: 0; margin: 0; }
        </style>
    </head>
    <body>
        <nav>
            <h1><a href="/" style="color: white; text-decoration: none;">Pet Store</a></h1>
            {arizona_template:render_slot(nav_links(CurrentUser))}
        </nav>
        <main>
            {arizona_template:render_slot(arizona_template:get_binding(inner_content, Bindings))}
        </main>
    </body>
    </html>
    """").

nav_links(undefined) ->
    arizona_template:from_html(~"""
    <div class="nav-links">
        <a href="/register">Register</a>
        <a href="/login">Log In</a>
    </div>
    """);
nav_links(User) ->
    Email = maps:get(email, User, ~""),
    arizona_template:from_html(~""""
    <div class="nav-links">
        <span class="user-email">{Email}</span>
        <form action="/logout" method="post" class="logout-form">
            <button type="submit" class="logout-btn">Log Out</button>
        </form>
    </div>
    """").
