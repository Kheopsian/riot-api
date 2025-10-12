# RiotAPI

An Elixir API for data encryption and verification using HMAC-SHA256.

## Features

This API provides REST endpoints for:
- **Encryption**: Base64 encoding of data
- **Decryption**: Decoding of encoded data
- **Signing**: HMAC-SHA256 signature generation
- **Verification**: Signature validation

## Installation and Configuration

### Dependencies

```elixir
def deps do
  [
    {:plug_cowboy, "~> 2.7"},
    {:jason, "~> 1.4"},
    {:plug_crypto, "~> 2.1"}
  ]
end
```

### Environment Variables

- `HMAC_SECRET`: Secret key for HMAC (optional, default: "super-secret-key")

## Getting Started

```bash
# Install dependencies
mix deps.get

# Start the server
mix run --no-halt
```

The server starts on port 4000.

## API Endpoints

### POST /encrypt

Encrypts payload data using Base64 encoding.

**Requête :**
```json
{
  "key1": "value1",
  "key2": "value2"
}
```

**Réponse :**
```json
{
  "key1": "dmFsdWUx",  // Base64 encoded
  "key2": "dmFsdWUy"
}
```

### POST /decrypt

Decrypts Base64 encoded data.

**Requête :**
```json
{
  "key1": "dmFsdWUx",
  "key2": "dmFsdWUy"
}
```

**Réponse :**
```json
{
  "key1": "value1",
  "key2": "value2"
}
```

### POST /sign

Generates an HMAC-SHA256 signature for the data.

**Requête :**
```json
{
  "key1": "value1",
  "key2": "value2"
}
```

**Réponse :**
```json
{
  "signature": "a1b2c3d4e5f6..."
}
```

### POST /verify

Verifies the signature of the data.

**Requête :**
```json
{
  "signature": "a1b2c3d4e5f6...",
  "data": {
    "key1": "value1",
    "key2": "value2"
  }
}
```

**Response:**
- `204 No Content`: Valid signature
- `400 Bad Request`: Invalid signature

## Architecture

The project uses a modular architecture with:

- **`RiotApi.Router`**: HTTP route handling
- **`RiotApi.Crypto`**: Main interface for crypto operations
- **`RiotApi.Crypto.Engine`**: Behaviour for encryption engines
- **`RiotApi.Crypto.Base64HmacEngine`**: Concrete implementation using Base64 and HMAC-SHA256

## Tests

```bash
mix test
```

## Docker

### Build the Image

```bash
docker-compose build
```

### Run the Container

```bash
docker-compose up
```

### CI/CD Pipeline

The project includes a GitHub Actions pipeline that:
1. Runs tests
2. Builds the Docker image
3. Publishes it to GitHub Container Registry (available at `ghcr.io/kheopsian/riot-api:latest`)

## Code Formatting

```bash
# Format code
mix format

# Check formatting
mix format --check-formatted
```

## Documentation

Generate documentation with ExDoc:

```bash
mix docs
```

