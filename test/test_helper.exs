ExUnit.start()

# Configuration for tests
Application.put_env(:plug_cowboy, :http, nil)

# Disable automatic application startup
ExUnit.configure(exclude: [integration: true])
