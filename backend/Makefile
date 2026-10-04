# Likho API. Run `make help` for the list.
.DEFAULT_GOAL := help
.PHONY: help run db db-reset up down test test-db lint build content content-bundle content-fixture docker tidy geoip admin

TEST_DB ?= postgres://likho:likho@localhost:5432/likho_test?sslmode=disable
COURSE  ?= english-handwriting

help: ## show the targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-16s %s\n", $$1, $$2}'

run: ## API on http://localhost:8080 (settings from .env)
	set -a && . ./.env && set +a && go run ./cmd/api

db: ## Postgres + Redis in Docker
	docker compose up -d postgres redis

db-reset: ## wipe the local database and cache (development)
	docker compose down -v && docker compose up -d postgres redis

up: ## everything in Docker (API included)
	docker compose up --build

down: ## stop Docker
	docker compose down

test: ## unit tests (no database)
	go test ./...

test-db: ## all tests, including the API on Postgres (needs `make db`)
	docker compose exec -T postgres psql -U likho -tc "SELECT 1 FROM pg_database WHERE datname='likho_test'" | grep -q 1 || \
		docker compose exec -T postgres createdb -U likho likho_test
	TEST_DATABASE_URL="$(TEST_DB)" go test -race -count=1 ./...

lint: ## go vet + formatting
	go vet ./...
	@test -z "$$(gofmt -l .)" || (gofmt -l . && echo "run gofmt -w ." && exit 1)

content: ## check every course (run after editing content/)
	go run ./cmd/content validate

content-bundle: ## print a course as the API serves it (COURSE=…)
	go run ./cmd/content bundle $(COURSE) -indent

content-fixture: ## refresh the app's test copy of the course
	go run ./cmd/content bundle $(COURSE) -indent -o ../app/test/fixtures/$(COURSE).json

build: ## static binary in bin/
	CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o bin/likho-api ./cmd/api

docker: ## production image
	docker build -t likho-api .

geoip: ## download the free DB-IP country database (CC BY 4.0) to geoip/ (set GEOIP_DB)
	mkdir -p geoip
	curl -fsSL "https://download.db-ip.com/free/dbip-country-lite-$$(date -u +%Y-%m).mmdb.gz" | gunzip > geoip/country.mmdb
	@echo "Saved geoip/country.mmdb. Set GEOIP_DB=./geoip/country.mmdb (attribution: IP Geolocation by DB-IP, https://db-ip.com)"

admin: ## build the admin panel (and its phone preview) for ADMIN_DIR=../admin/dist
	cd ../admin && npm ci && scripts/build-preview.sh && npm run build

tidy:
	go mod tidy
