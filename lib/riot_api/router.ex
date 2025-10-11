defmodule RiotApi.Router do
  use Plug.Router
  alias RiotApi.Crypto

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  post "/encrypt" do
    payload = conn.body_params
    encrypted_payload = Crypto.encrypt_payload(payload)
    send_json(conn, 200, encrypted_payload)
  end

  post "/decrypt" do
    payload = conn.body_params
    decrypted_payload = Crypto.decrypt_payload(payload)
    send_json(conn, 200, decrypted_payload)
  end

  post "/sign" do
    payload = conn.body_params
    signed_payload = Crypto.sign_payload(payload)
    send_json(conn, 200, signed_payload)
  end

  post "/verify" do
    payload = conn.body_params

    case Crypto.verify_payload(payload) do
      true -> send_resp(conn, 204, "")
      false -> send_resp(conn, 400, "Invalid Signature")
    end
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  defp send_json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end
end
