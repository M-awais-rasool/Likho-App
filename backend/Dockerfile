# Production image of the API:   docker build -t likho-api .   (from backend/)
# The learning content (content/) is built into the binary; the pictures and
# recordings are a folder mounted at /media (see ../deploy/docker-compose.yml).

FROM golang:1.27-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/likho-api ./cmd/api

# tiny image: just the binary, no shell, runs as a non-root user
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/likho-api /likho-api
ENV APP_ENV=production PORT=8080 MEDIA_DIR=/media
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/likho-api"]
