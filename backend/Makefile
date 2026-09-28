.PHONY: run db up down test test-db build vet tidy

# Postgres + Redis in Docker (for `make run`)
db:
	docker compose up -d postgres redis

# API on your machine with .env
run:
	set -a && . ./.env && set +a && go run .

# everything in Docker
up:
	docker compose up --build

down:
	docker compose down

# unit tests (no database needed)
test:
	go test ./...

# all tests, including the API tests on Postgres (needs `make db`)
test-db:
	docker compose exec -T postgres psql -U likho -tc "SELECT 1 FROM pg_database WHERE datname='likho_test'" | grep -q 1 || \
		docker compose exec -T postgres createdb -U likho likho_test
	TEST_DATABASE_URL="postgres://likho:likho@localhost:5432/likho_test?sslmode=disable" go test -race -count=1 ./...

build:
	CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o bin/likho-api .

vet:
	go vet ./...

tidy:
	go mod tidy
