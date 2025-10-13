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

# Stage 2: Runtime - Debian slim (compatible avec le binaire Erlang)
FROM debian:bookworm-slim

# Install only runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    libncurses6 \
    locales && \
    rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

# Copy the release from builder
COPY --from=builder /app/_build/prod/rel/riot_api ./

CMD ["./bin/riot_api", "start"]