defmodule RiotApi.Crypto do
  @engine RiotApi.Crypto.Base64HmacEngine

  def encrypt_payload(payload) when is_map(payload) do
    for {key, value} <- payload, into: %{} do
      {key, @engine.encrypt(value)}
    end
  end

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

  def sign_payload(payload) when is_map(payload) do
    %{signature: @engine.sign(payload)}
  end

  def verify_payload(%{"signature" => signature, "data" => data}) when is_map(data) do
    @engine.verify(data, signature)
  end

  def verify_payload(%{signature: signature, data: data}) when is_map(data) do
    @engine.verify(data, signature)
  end

  def verify_payload(_), do: false
end
