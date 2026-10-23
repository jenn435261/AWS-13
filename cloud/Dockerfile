# Multi-stage build for the Resilience Network Go API.
# Runs the same cmd/api HTTP server used locally; reads $PORT (Heroku injects
# it) and AWS creds + BEDROCK_MODEL_ID from config vars/env to call Bedrock.
FROM golang:1.26-bookworm AS build
WORKDIR /src
# Module files first for layer caching.
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /out/resilience-api ./cmd/api

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/resilience-api /resilience-api
# Heroku sets $PORT at runtime; the API defaults to 8080 locally.
ENV PORT=8080
USER nonroot:nonroot
ENTRYPOINT ["/resilience-api"]
