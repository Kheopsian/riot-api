defmodule TestHelpers do
  import Plug.Test
  import Plug.Conn
  alias RiotApi.Router

  @router_opts Router.init([])

  @doc "Crée une connexion HTTP de test avec les headers nécessaires"
  def http_conn(method, path, body \\ %{}) do
    conn(method, path, body)
    |> put_req_header("content-type", "application/json")
  end

  @doc "Exécute une requête et retourne le body parsé en JSON"
  def execute_and_parse(conn) do
    conn = Router.call(conn, @router_opts)
    body = case conn.resp_body do
      "" -> nil
      body_str ->
        case Jason.decode(body_str) do
          {:ok, decoded} -> decoded
          {:error, _} -> nil  # Si ce n'est pas du JSON (comme "Invalid Signature"), retourner nil
        end
    end
    {conn, body}
  end

  @doc "Exécute une requête POST et retourne la connexion et le body parsé"
  def post_and_parse(path, payload) do
    http_conn(:post, path, payload)
    |> execute_and_parse()
  end

  @doc "Appel HTTP encrypt via le router"
  def http_encrypt(payload) do
    {conn, body} = post_and_parse("/encrypt", payload)
    {conn.status, body}
  end

  @doc "Appel HTTP decrypt via le router"
  def http_decrypt(payload) do
    {conn, body} = post_and_parse("/decrypt", payload)
    {conn.status, body}
  end

  @doc "Appel HTTP sign via le router"
  def http_sign(payload) do
    {conn, body} = post_and_parse("/sign", payload)
    {conn.status, body}
  end

  @doc "Appel HTTP verify via le router"
  def http_verify(signature, data) do
    payload = %{"signature" => signature, "data" => data}
    {conn, _body} = post_and_parse("/verify", payload)
    conn.status
  end

  @doc "Round-trip encrypt -> decrypt"
  def encrypt_decrypt_roundtrip(payload) do
    {200, encrypted} = http_encrypt(payload)
    {200, decrypted} = http_decrypt(encrypted)
    decrypted
  end

  @doc "Round-trip sign -> verify"
  def sign_verify_roundtrip(data) do
    {200, signed} = http_sign(data)
    status = http_verify(signed["signature"], data)
    {status, signed["signature"]}
  end

  @doc "Cas de test simples pour les payloads"
  def simple_payloads do
    [
      %{},
      %{"simple" => "string"},
      %{"number" => 42},
      %{"boolean" => true},
      %{"nil_value" => nil}
    ]
  end

  @doc "Cas de test complexes pour les payloads"
  def complex_payloads do
    [
      %{"nested" => %{"data" => "value"}},
      %{"array" => [1, 2, 3]},
      %{"mixed" => %{
        "string" => "test",
        "number" => 42,
        "boolean" => true,
        "nil" => nil,
        "array" => [1, 2, 3],
        "nested" => %{"deep" => "value"}
      }}
    ]
  end

  @doc "Tous les cas de test pour les payloads"
  def all_payloads do
    simple_payloads() ++ complex_payloads()
  end

  @doc "Payload très complexe pour les tests d'intégration"
  def very_complex_payload do
    %{
      "user" => %{
        "id" => 123,
        "name" => "John Doe",
        "email" => "john@example.com",
        "profile" => %{
          "age" => 30,
          "preferences" => %{
            "theme" => "dark",
            "notifications" => true,
            "privacy" => %{
              "share_data" => false,
              "marketing_emails" => true
            }
          }
        }
      },
      "sessions" => [
        %{"id" => 1, "created_at" => "2023-01-01T12:00:00Z", "active" => true},
        %{"id" => 2, "created_at" => "2023-01-02T14:30:00Z", "active" => false}
      ],
      "metadata" => nil,
      "tags" => ["user", "active", "premium"],
      "counters" => %{"login_count" => 42, "last_login" => 1672574400}
    }
  end
end
