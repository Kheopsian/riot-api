defmodule RiotApi.Crypto do
  @moduledoc """
  Provides cryptographic operations for Riot API payloads.

  This module offers functions to encrypt, decrypt, sign, and verify payload maps
  using a configurable crypto engine. The default engine is Base64HmacEngine.
  """

  @engine RiotApi.Crypto.Base64HmacEngine

  @doc """
  Encrypts the values in a payload map.

  Takes a map and encrypts each value using the configured crypto engine,
  returning a new map with the same keys but encrypted values.

  ## Parameters

  - payload: A map with string or atom keys and values to encrypt.

  ## Returns

  A map with encrypted values.

  ## Examples

      iex> RiotApi.Crypto.encrypt_payload(%{"key" => "value"})
      %{"key" => "encrypted_value"}
  """
  def encrypt_payload(payload) when is_map(payload) do
    for {key, value} <- payload, into: %{} do
      {key, @engine.encrypt(value)}
    end
  end

  @doc """
  Decrypts the values in a payload map.

  Iterates through the map and decrypts binary values using the crypto engine.
  Non-binary values are left unchanged.

  ## Parameters

  - payload: A map with potentially encrypted values.

  ## Returns

  A map with decrypted values where applicable.
  """
  def decrypt_payload(payload) when is_map(payload) do
    for {key, value} <- payload, into: %{} do
      decrypted_value = if is_binary(value) do
        @engine.decrypt(value)
      else
        value
      end

      # Keep keys as they are (no atom/string conversion)
      {key, decrypted_value}
    end
  end

  @doc """
  Signs a payload map.

  Generates a signature for the given payload using the crypto engine.

  ## Parameters

  - payload: The map to sign.

  ## Returns

  A map containing the signature.

  ## Examples

      iex> RiotApi.Crypto.sign_payload(%{"data" => "value"})
      %{signature: "signature_string"}
  """
  def sign_payload(payload) when is_map(payload) do
    %{signature: @engine.sign(payload)}
  end

  @doc """
  Verifies a payload with a signature.

  Checks if the provided signature matches the data in the payload.
  Accepts payloads with string keys ("signature", "data") or atom keys (:signature, :data).

  ## Parameters

  - payload: A map containing "signature" or :signature and "data" or :data keys.

  ## Returns

  true if verification succeeds, false otherwise.
  """
  def verify_payload(%{"signature" => signature, "data" => data}) when is_map(data) do
    @engine.verify(data, signature)
  end

  def verify_payload(%{signature: signature, data: data}) when is_map(data) do
    @engine.verify(data, signature)
  end

  def verify_payload(_), do: false
end
