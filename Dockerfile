FROM elixir:1.18-slim

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set the working directory
WORKDIR /app

# Copy mix.exs and mix.lock
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get --only prod

# Copy the rest of the application
COPY . .

# Compile the application
RUN MIX_ENV=prod mix compile

# Run the application
CMD ["mix", "run", "--no-halt"]