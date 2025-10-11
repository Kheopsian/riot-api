# RiotAPI

An Elixir API for data encryption and verification using HMAC-SHA256.

## Installation

If available on Hex, the package can be installed by adding `riot_api` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:riot_api, "~> 0.1.0"}
  ]
end
```

## Elixir Formatter

This project uses the Elixir formatter to maintain consistent code style. The `.formatter.exs` configuration file defines which files to format.

### Usage

To format all project files:

```bash
mix format
```

To check if files are properly formatted (without modifying them):

```bash
mix format --check-formatted
```

### Configuration

The formatter is configured to format:
- `.exs` files in the root directory (mix.exs, .formatter.exs)
- All `.ex` and `.exs` files in the `config/`, `lib/`, and `test/` directories

## Documentation

The documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/riot_api>.

