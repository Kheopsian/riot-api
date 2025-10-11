defmodule RiotApi.Crypto.Base64HmacEngine do
  @behaviour RiotApi.Crypto.Engine

  @hmac_secret "super-secret-key"

  @impl RiotApi.Crypto.Engine
  def encrypt(value) do
    value
    |> Jason.encode!()
    |> Base.encode64()
  end

  @impl RiotApi.Crypto.Engine
  def decrypt(value) do
    case Base.decode64(value) do
      {:ok, decoded} ->
        case Jason.decode(decoded) do
          {:ok, json} -> json
          _ -> decoded
        end

      :error ->
        value
    end
  end

  @impl RiotApi.Crypto.Engine
  def sign(data) do
    data_list = data |> Map.to_list()
    sorted_list = data_list |> Enum.sort_by(fn {k, _v} -> k end)
    canonical_map = sorted_list |> Map.new()
    canonical_string = canonical_map |> Jason.encode!()

    signature =
      :crypto.mac(:hmac, :sha256, @hmac_secret, canonical_string)
      |> Base.encode16(case: :lower)

    signature
  end

  @impl RiotApi.Crypto.Engine
  def verify(data, signature) do
    # Validation: reject empty or invalid signatures
    if is_nil(signature) or signature == "" or not is_binary(signature) do
      false
    else
      expected_signature = sign(data)
      Plug.Crypto.secure_compare(expected_signature, signature)
    end
  end
end
