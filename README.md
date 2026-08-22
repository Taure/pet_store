# Pet Store

A sample REST API built with [Nova](https://github.com/novaframework/nova) and [Kura](https://github.com/Taure/kura), demonstrating how to build a database-backed Erlang web application with authentication and resource ownership.

## What This Demonstrates

- **Schema definition** — `pet.erl` and `pet_store_user.erl` define typed schemas with `kura_schema`
- **Changesets** — controllers cast and validate incoming JSON with `kura_changeset`
- **Query builder** — listing pets uses `kura_query:from/1` piped through `kura_repo_worker:all/2`
- **Repo pattern** — `pet_store_repo.erl` wraps `kura_repo_worker` for a clean API
- **Migrations** — versioned DDL in `migrations/` managed by `kura_migrator`
- **Nova routing** — `pet_store_router.erl` maps HTTP verbs to controller functions
- **Authentication** — bcrypt password hashing, session tokens with SHA-256, cookie-based sessions
- **Resource ownership** — pets belong to users; create/update/delete require authentication and ownership

## API Endpoints

### Public

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/pets` | List all pets |
| `GET` | `/api/pets/:id` | Get a pet by ID |
| `POST` | `/api/register` | Register a new user |
| `POST` | `/api/login` | Log in, returns session cookie |

### Authenticated

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/pets` | Create a pet (owned by current user) |
| `PUT` | `/api/pets/:id` | Update a pet (owner only) |
| `DELETE` | `/api/pets/:id` | Delete a pet (owner only) |
| `GET` | `/api/me` | Get current user |
| `PUT` | `/api/me/password` | Change password |
| `PUT` | `/api/me/email` | Change email |
| `DELETE` | `/api/logout` | Log out |

## Project Structure

```
pet_store/
├── src/
│   ├── schemas/
│   │   ├── pet.erl                    # Pet schema
│   │   ├── pet_store_user.erl         # User schema
│   │   └── pet_store_user_token.erl   # Session token schema
│   ├── controllers/
│   │   ├── pets_controller.erl        # Pet API CRUD (with ownership)
│   │   └── pet_store_*_controller.erl # User/session API controllers
│   ├── migrations/                    # Versioned DDL migrations
│   ├── pet_store_app.erl             # Application start
│   ├── pet_store_sup.erl             # Supervisor
│   ├── pet_store_repo.erl            # Kura repo wrapper
│   ├── pet_store_accounts.erl        # Account context (registration, auth, tokens)
│   ├── pet_store_auth.erl            # Auth plug (session cookie → user)
│   └── pet_store_router.erl          # Nova routes
├── config/
│   ├── dev_sys.config
│   └── test_sys.config
├── test/
│   ├── migrations_SUITE.erl
│   ├── pets_api_SUITE.erl
│   ├── pet_store_auth_SUITE.erl
│   └── pet_store_auth_page_SUITE.erl
└── docker-compose.yml
```

## Getting Started

### Prerequisites

- Erlang/OTP 27+
- Docker (for PostgreSQL)

### Setup

```bash
# Start PostgreSQL
make setup

# Start the server (port 8080)
make server
```

### Try It Out

```bash
# Register a user
curl -X POST http://localhost:8080/api/register \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "secret123456", "password_confirmation": "secret123456"}'

# Log in (save the session cookie)
curl -c cookies.txt -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "secret123456"}'

# Create a pet (authenticated)
curl -b cookies.txt -X POST http://localhost:8080/api/pets \
  -H "Content-Type: application/json" \
  -d '{"name": "Luna", "species": "cat", "breed": "Siamese", "age": 3}'

# List all pets (public)
curl http://localhost:8080/api/pets

# Get a pet (public)
curl http://localhost:8080/api/pets/1

# Update a pet (owner only)
curl -b cookies.txt -X PUT http://localhost:8080/api/pets/1 \
  -H "Content-Type: application/json" \
  -d '{"age": 4}'

# Delete a pet (owner only)
curl -b cookies.txt -X DELETE http://localhost:8080/api/pets/1
```

### Running Tests

```bash
make test
```

This starts PostgreSQL, creates the test database, runs Common Test suites, and tears down the container.

## How It Works

### Schema

Schemas map Erlang fields to PostgreSQL columns with types:

```erlang
%% pet.erl
fields() ->
    [#kura_field{name = id, type = id, primary_key = true, nullable = false},
     #kura_field{name = user_id, type = integer, nullable = false},
     #kura_field{name = name, type = string, nullable = false},
     #kura_field{name = species, type = string, nullable = false},
     #kura_field{name = breed, type = string},
     #kura_field{name = age, type = integer},
     #kura_field{name = weight, type = float},
     ...].
```

### Controller

Controllers cast JSON params, validate, and enforce ownership:

```erlang
create(#{json := Params} = Req) ->
    #{id := UserId} = maps:get(auth_data, Req),
    CS = kura_changeset:cast(pet, #{}, Params, [name, species, breed, age, weight]),
    CS1 = kura_changeset:validate_required(CS, [name, species]),
    CS2 = kura_changeset:put_change(CS1, user_id, UserId),
    case pet_store_repo:insert(CS2) of
        {ok, Pet} ->
            {status, 201, #{}, #{data => serialize(Pet)}};
        {error, #kura_changeset{errors = Errors}} ->
            {status, 422, #{}, #{errors => format_errors(Errors)}}
    end.
```

### Authentication

Session-based auth using bcrypt + SHA-256 hashed tokens stored in PostgreSQL. The `pet_store_auth` module reads the session cookie and injects the user into `auth_data` for protected routes.

### Migrations

Migrations run automatically on application start:

```erlang
%% m20250214130000_add_microchip_to_pets.erl
up() ->
    [{alter_table, <<"pets">>, [
        {add_column, #kura_column{name = microchip_id, type = string}}
    ]}].
```
