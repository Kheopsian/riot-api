# Stage 1: Build
FROM elixir:1.18-slim AS builder

# Install ca-certificates
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get --only prod

# Copy application code
COPY . .

# Compile the application
RUN MIX_ENV=prod mix compile && \
    MIX_ENV=prod mix release

# Stage 2: Runtime - Alpine minimal
FROM alpine:3.21

# Install only runtime dependencies (no OpenSSL with CVE-2025-9230)
RUN apk add --no-cache \
    erlang \
    erlang-dev \
    ncurses-libs

WORKDIR /app

# Copy the release from builder
COPY --from=builder /app/_build/prod/rel/riot_api ./

EXPOSE 4000

CMD ["./bin/riot_api", "start"]