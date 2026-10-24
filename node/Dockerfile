# Multi-stage build for the Resilience Node daemon.
# The node is a self-contained Go module (its own go.mod, no dependency on the
# cloud module). It builds a static binary and ships it on distroless.
FROM golang:1.26-bookworm AS build
WORKDIR /src
# Module files first for layer caching.
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /out/resilience-node ./cmd/resilience-node

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/resilience-node /resilience-node
# Default listen address; override with $HTTP_ADDR. The daemon also reads
# DATA_DIR, CLOUD_BASE_URL, APK_DIR, MAP_DIR, READINESS_DIR from the env.
ENV HTTP_ADDR=:8090
EXPOSE 8090
USER nonroot:nonroot
ENTRYPOINT ["/resilience-node"]
