ExUnit.start()

# Configuration for tests
Application.put_env(:plug_cowboy, :http, nil)

# Disable automatic application startup
ExUnit.configure(exclude: [integration: true])

# Load test helpers
Code.require_file("riot_api/test_helper.exs", __DIR__)
