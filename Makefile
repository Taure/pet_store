.PHONY: setup server clean test test.setup test.teardown

setup:
	docker compose up -d
	@echo "Waiting for Postgres..."
	@until docker compose exec postgres pg_isready -q 2>/dev/null; do sleep 1; done
	docker compose exec postgres psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='pet_store_dev'" | grep -q 1 || \
		docker compose exec postgres psql -U postgres -c "CREATE DATABASE pet_store_dev;"

server:
	rebar3 shell

clean:
	rebar3 clean

test.setup:
	@# Stop any existing postgres on 5432
	@docker compose down 2>/dev/null || true
	docker compose up -d
	@echo "Waiting for Postgres..."
	@until docker compose exec postgres pg_isready -q 2>/dev/null; do sleep 1; done
	@docker compose exec postgres psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='pet_store_test'" | grep -q 1 || \
		docker compose exec postgres psql -U postgres -c "CREATE DATABASE pet_store_test;"

test.teardown:
	docker compose down

test: test.setup
	rebar3 ct --sys_config config/test_sys.config; \
	EXIT_CODE=$$?; \
	$(MAKE) test.teardown; \
	exit $$EXIT_CODE
