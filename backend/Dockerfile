# Build from the repository root (the image also ships the course content):
#   docker build -f backend/Dockerfile -t likho-api .

FROM golang:1.27-alpine AS build
WORKDIR /src
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/likho-api .

# tiny image: just the binary, no shell, runs as a non-root user
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/likho-api /likho-api
COPY assets/data/course.json /content/course.json
ENV APP_ENV=production PORT=8080 COURSE_FILE=/content/course.json
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/likho-api"]
