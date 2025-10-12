defmodule RiotApi.Crypto.Engine do
  @moduledoc """
  Defines the behavior for crypto engines in RiotApi.

  This module specifies the callback functions that any crypto engine must implement.
  Engines are responsible for encrypting, decrypting, signing, and verifying data.
  The default implementation is Base64HmacEngine.
  """

  @doc """
  Callback for encrypting a single value.

  Takes any value, encodes it to JSON, and then base64-encodes the result.
  """
  @callback encrypt(value :: any) :: String.t()

  @doc """
  Callback for decrypting an encrypted string.

  Decodes a base64-encoded string and attempts to parse it as JSON.
  Returns the original value if successful, otherwise the decoded string.
  """
  @callback decrypt(value :: String.t()) :: any

  @doc """
  Callback for signing a map of data.

  Creates a canonical JSON representation of the map (sorted keys) and generates
  an HMAC-SHA256 signature using a secret key.
  """
  @callback sign(data :: map) :: String.t()

  @doc """
  Callback for verifying a signature against data.

  Computes the expected signature for the data and compares it securely
  with the provided signature.
  """
  @callback verify(data :: map, signature :: String.t()) :: boolean
end
