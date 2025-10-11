defmodule RiotApi.Crypto.Engine do
  @doc "Callback for encrypting a value."
  @callback encrypt(value :: any) :: String.t()

  @doc "Callback for decrypting a string."
  @callback decrypt(value :: String.t()) :: any

  @doc "Callback for signing data."
  @callback sign(data :: map) :: String.t()

  @doc "Callback for verifying a signature."
  @callback verify(data :: map, signature :: String.t()) :: boolean
end
