# Pet Store

A sample REST API built with [Nova](https://github.com/novaframework/nova) and [Kura](https://github.com/Taure/kura), demonstrating how to build a database-backed Erlang web application.

## What This Demonstrates

- **Schema definition** — `pet.erl` defines a typed schema with `kura_schema`
- **Changesets** — `pets_controller.erl` casts and validates incoming JSON with `kura_changeset`
- **Query builder** — listing pets uses `kura_query:from/1` piped through `kura_repo_worker:all/2`
- **Repo pattern** — `pet_store_repo.erl` wraps `kura_repo_worker` for a clean API
- **Migrations** — versioned DDL in `migrations/` managed by `kura_migrator`
- **Nova routing** — `pet_store_router.erl` maps HTTP verbs to controller functions

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/pets` | List all pets |
| `POST` | `/api/pets` | Create a pet |
| `GET` | `/api/pets/:id` | Get a pet by ID |
| `PUT` | `/api/pets/:id` | Update a pet |
| `DELETE` | `/api/pets/:id` | Delete a pet |

## Project Structure

```
pet_store/
├── src/
│   ├── schemas/
│   │   └── pet.erl              # Kura schema
│   ├── controllers/
│   │   └── pets_controller.erl  # CRUD handlers
│   ├── pet_store_app.erl        # Application start, runs migrations
│   ├── pet_store_sup.erl        # Supervisor
│   ├── pet_store_repo.erl       # Kura repo wrapper
│   └── pet_store_router.erl     # Nova routes
├── src/
│   ├── migrations/
│   │   ├── m20250214120000_create_pets.erl
│   │   └── m20250214130000_add_microchip_to_pets.erl
├── config/
│   ├── dev_sys.config
│   └── test_sys.config
├── test/
│   ├── pets_api_SUITE.erl
│   └── migrations_SUITE.erl
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
# Create a pet
curl -X POST http://localhost:8080/api/pets \
  -H "Content-Type: application/json" \
  -d '{"name": "Luna", "species": "cat", "breed": "Siamese", "age": 3}'

# List all pets
curl http://localhost:8080/api/pets

# Get a pet
curl http://localhost:8080/api/pets/1

# Update a pet
curl -X PUT http://localhost:8080/api/pets/1 \
  -H "Content-Type: application/json" \
  -d '{"age": 4}'

# Delete a pet
curl -X DELETE http://localhost:8080/api/pets/1
```

### Running Tests

```bash
make test
```

This starts PostgreSQL, creates the test database, runs Common Test suites, and tears down the container.

## How It Works

### Schema

The `pet` schema maps Erlang fields to PostgreSQL columns with types:

```erlang
fields() ->
    [#kura_field{name = id, type = id, primary_key = true, nullable = false},
     #kura_field{name = name, type = string, nullable = false},
     #kura_field{name = species, type = string, nullable = false},
     #kura_field{name = breed, type = string},
     #kura_field{name = age, type = integer},
     #kura_field{name = weight, type = float},
     #kura_field{name = inserted_at, type = utc_datetime},
     #kura_field{name = updated_at, type = utc_datetime}].
```

### Controller

The controller casts JSON params, validates, and delegates to the repo:

```erlang
create(#{json := Params} = _Req) ->
    CS = kura_changeset:cast(pet, #{}, Params, [name, species, breed, age, weight]),
    CS1 = kura_changeset:validate_required(CS, [name, species]),
    case pet_store_repo:insert(CS1) of
        {ok, Pet} ->
            {status, 201, #{}, #{data => serialize(Pet)}};
        {error, #kura_changeset{errors = Errors}} ->
            {status, 422, #{}, #{errors => format_errors(Errors)}}
    end.
```

### Migrations

Migrations run automatically on application start. The app defines the table structure and can evolve it over time:

```erlang
%% m20250214130000_add_microchip_to_pets.erl
up() ->
    [{alter_table, <<"pets">>, [
        {add_column, #kura_column{name = microchip_id, type = string}}
    ]}].
```
