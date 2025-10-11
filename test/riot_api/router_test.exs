defmodule RiotApi.RouterTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias RiotApi.Router

  @opts Router.init([])

  describe "POST /encrypt" do
    test "encrypts a simple payload" do
      payload = %{name: "John", age: 30}
      conn = conn(:post, "/encrypt", payload) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200

      response = Jason.decode!(conn.resp_body)
      assert is_map(response)
      assert Map.has_key?(response, "name")
      assert Map.has_key?(response, "age")

      # Values must be different from originals (encrypted)
      assert response["name"] != "John"
      assert response["age"] != 30

      # Values must be base64 strings
      assert is_binary(response["name"])
      assert is_binary(response["age"])
    end

    test "encrypts a complex payload" do
      payload = %{
        user: %{name: "John", email: "john@example.com"},
        preferences: [1, 2, 3],
        metadata: nil
      }
      conn = conn(:post, "/encrypt", payload) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200

      response = Jason.decode!(conn.resp_body)
      assert is_map(response)
      assert Map.has_key?(response, "user")
      assert Map.has_key?(response, "preferences")
      assert Map.has_key?(response, "metadata")

      # Values must be base64 strings
      assert is_binary(response["user"])
      assert is_binary(response["preferences"])
      assert is_binary(response["metadata"])
    end

    test "encrypts an empty payload" do
      payload = %{}
      conn = conn(:post, "/encrypt", payload) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200

      response = Jason.decode!(conn.resp_body)
      assert response == %{}
    end

    test "returns an error for invalid JSON" do
      conn = conn(:post, "/encrypt", "invalid json") |> put_req_header("content-type", "application/json")

      # The JSON parser raises an exception for invalid JSON
      assert_raise Plug.Parsers.ParseError, fn ->
        Router.call(conn, @opts)
      end
    end
  end

  describe "POST /decrypt" do
    test "decrypts a previously encrypted payload" do
      # First, encrypt a payload
      original = %{name: "John", age: 30}
      encrypt_conn = conn(:post, "/encrypt", original) |> put_req_header("content-type", "application/json")
      encrypt_conn = Router.call(encrypt_conn, @opts)
      encrypted = Jason.decode!(encrypt_conn.resp_body)

      # Then, decrypt it
      conn = conn(:post, "/decrypt", encrypted) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200

      response = Jason.decode!(conn.resp_body)
      # Atom keys become strings after decryption
      expected = %{"name" => "John", "age" => 30}
      assert response == expected
    end

    test "decrypts a partially encrypted payload" do
      # Simulate a payload with already encrypted values and non-binary values
      payload = %{
        encrypted_value: Base.encode64(Jason.encode!("test")),
        already_number: 42,
        already_boolean: true,
        already_nil: nil
      }

      conn = conn(:post, "/decrypt", payload) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200

      response = Jason.decode!(conn.resp_body)
      assert response["encrypted_value"] == "test"
      assert response["already_number"] == 42
      assert response["already_boolean"] == true
      assert response["already_nil"] == nil
    end

    test "decrypts an empty payload" do
      payload = %{}
      conn = conn(:post, "/decrypt", payload) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200

      response = Jason.decode!(conn.resp_body)
      assert response == %{}
    end

    test "returns an error for invalid JSON" do
      conn = conn(:post, "/decrypt", "invalid json") |> put_req_header("content-type", "application/json")

      # The JSON parser raises an exception for invalid JSON
      assert_raise Plug.Parsers.ParseError, fn ->
        Router.call(conn, @opts)
      end
    end
  end

  describe "POST /sign" do
    test "generates a signature for a payload" do
      payload = %{name: "John", age: 30}
      conn = conn(:post, "/sign", payload) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200

      response = Jason.decode!(conn.resp_body)
      assert is_map(response)
      assert Map.has_key?(response, "signature")
      assert is_binary(response["signature"])
      assert String.length(response["signature"]) == 64  # SHA256 in hexadecimal
    end

    test "generates a signature for a complex payload" do
      payload = %{
        user: %{name: "John", email: "john@example.com"},
        preferences: [1, 2, 3],
        metadata: nil
      }
      conn = conn(:post, "/sign", payload) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200

      response = Jason.decode!(conn.resp_body)
      assert is_map(response)
      assert Map.has_key?(response, "signature")
      assert is_binary(response["signature"])
    end

    test "generates a signature for an empty payload" do
      payload = %{}
      conn = conn(:post, "/sign", payload) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200

      response = Jason.decode!(conn.resp_body)
      assert is_map(response)
      assert Map.has_key?(response, "signature")
      assert is_binary(response["signature"])
    end

    test "returns an error for invalid JSON" do
      conn = conn(:post, "/sign", "invalid json") |> put_req_header("content-type", "application/json")

      # The JSON parser raises an exception for invalid JSON
      assert_raise Plug.Parsers.ParseError, fn ->
        Router.call(conn, @opts)
      end
    end
  end

  describe "POST /verify" do
    test "verifies a valid signature" do
      # First, sign a payload
      data = %{name: "John", age: 30}
      sign_conn = conn(:post, "/sign", data) |> put_req_header("content-type", "application/json")
      sign_conn = Router.call(sign_conn, @opts)
      signed = Jason.decode!(sign_conn.resp_body)

      # Then, verify the signature
      payload = %{signature: signed["signature"], data: data}
      conn = conn(:post, "/verify", payload) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 204
      assert conn.resp_body == ""
    end

    test "rejects an invalid signature" do
      data = %{name: "John", age: 30}
      payload = %{signature: "invalid_signature", data: data}
      conn = conn(:post, "/verify", payload) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 400
      assert conn.resp_body == "Invalid Signature"
    end

    test "rejects a signature for modified data" do
      # First, sign a payload
      original_data = %{name: "John", age: 30}
      sign_conn = conn(:post, "/sign", original_data) |> put_req_header("content-type", "application/json")
      sign_conn = Router.call(sign_conn, @opts)
      signed = Jason.decode!(sign_conn.resp_body)

      # Then, modify the data and try to verify
      modified_data = %{name: "John", age: 31}
      payload = %{signature: signed["signature"], data: modified_data}
      conn = conn(:post, "/verify", payload) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 400
      assert conn.resp_body == "Invalid Signature"
    end

    test "rejects a payload with invalid structure" do
      # Incorrect structure - no "signature" key
      payload1 = %{data: %{name: "John"}}
      conn = conn(:post, "/verify", payload1) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)
      assert conn.state == :sent
      assert conn.status == 400
      assert conn.resp_body == "Invalid Signature"

      # Incorrect structure - no "data" key
      payload2 = %{signature: "some_signature"}
      conn = conn(:post, "/verify", payload2) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)
      assert conn.state == :sent
      assert conn.status == 400
      assert conn.resp_body == "Invalid Signature"

      # Incorrect structure - data is not a map
      payload3 = %{signature: "some_signature", data: "not a map"}
      conn = conn(:post, "/verify", payload3) |> put_req_header("content-type", "application/json")
      conn = Router.call(conn, @opts)
      assert conn.state == :sent
      assert conn.status == 400
      assert conn.resp_body == "Invalid Signature"
    end

    test "returns an error for invalid JSON" do
      conn = conn(:post, "/verify", "invalid json") |> put_req_header("content-type", "application/json")

      # The JSON parser raises an exception for invalid JSON
      assert_raise Plug.Parsers.ParseError, fn ->
        Router.call(conn, @opts)
      end
    end
  end

  describe "invalid routes" do
    test "returns 404 for a non-existent route" do
      conn = conn(:get, "/unknown") |> Router.call(@opts)

      assert conn.state == :sent
      assert conn.status == 404
      assert conn.resp_body == "Not Found"
    end

    test "returns 404 for an unsupported HTTP method on an existing route" do
      conn = conn(:get, "/encrypt") |> Router.call(@opts)

      assert conn.state == :sent
      assert conn.status == 404
      assert conn.resp_body == "Not Found"
    end
  end

  describe "complete integration tests" do
    test "complete flow: encrypt -> sign -> verify -> decrypt" do
      # Use string keys since JSON will convert them anyway
      original = %{
        "user" => %{"name" => "John Doe", "email" => "john@example.com"},
        "preferences" => %{
          "theme" => "dark",
          "notifications" => true,
          "privacy" => %{"share_data" => false}
        },
        "last_login" => "2023-01-01T12:00:00Z",
        "active_sessions" => [1, 2, 3]
      }

      # Step 1: Encrypt
      encrypt_conn = conn(:post, "/encrypt", original) |> put_req_header("content-type", "application/json")
      encrypt_conn = Router.call(encrypt_conn, @opts)
      assert encrypt_conn.status == 200
      encrypted = Jason.decode!(encrypt_conn.resp_body)

      # Step 2: Sign
      sign_conn = conn(:post, "/sign", encrypted) |> put_req_header("content-type", "application/json")
      sign_conn = Router.call(sign_conn, @opts)
      assert sign_conn.status == 200
      signed = Jason.decode!(sign_conn.resp_body)

      # Step 3: Verify
      payload = %{"signature" => signed["signature"], "data" => encrypted}
      verify_conn = conn(:post, "/verify", payload) |> put_req_header("content-type", "application/json")
      verify_conn = Router.call(verify_conn, @opts)
      assert verify_conn.status == 204

      # Step 4: Decrypt
      decrypt_conn = conn(:post, "/decrypt", encrypted) |> put_req_header("content-type", "application/json")
      decrypt_conn = Router.call(decrypt_conn, @opts)
      assert decrypt_conn.status == 200
      decrypted = Jason.decode!(decrypt_conn.resp_body)

      # Final verification - JSON preserves string keys
      assert decrypted == original
    end

    test "encrypt -> decrypt flow with different data" do
      # Use string keys since JSON will convert them anyway
      test_cases = [
        %{"simple" => "string"},
        %{"number" => 42},
        %{"boolean" => true},
        %{"nil_value" => nil},
        %{"array" => [1, 2, 3]},
        %{"mixed" => %{
          "string" => "test",
          "number" => 42,
          "boolean" => true,
          "nil" => nil,
          "array" => [1, 2, 3]
        }},
        %{}
      ]

      for original <- test_cases do
        # Encrypt
        encrypt_conn = conn(:post, "/encrypt", original) |> put_req_header("content-type", "application/json")
        encrypt_conn = Router.call(encrypt_conn, @opts)
        assert encrypt_conn.status == 200
        encrypted = Jason.decode!(encrypt_conn.resp_body)

        # Decrypt
        decrypt_conn = conn(:post, "/decrypt", encrypted) |> put_req_header("content-type", "application/json")
        decrypt_conn = Router.call(decrypt_conn, @opts)
        assert decrypt_conn.status == 200
        decrypted = Jason.decode!(decrypt_conn.resp_body)

        # JSON preserves string keys
        assert decrypted == original, "Round-trip failed for: #{inspect(original)}"
      end
    end

    test "encrypt -> decrypt flow for nested maps" do
      # Use string keys since JSON will convert them anyway
      test_cases = [
        %{"nested" => %{"data" => "value"}},
        %{"mixed" => %{
          "string" => "test",
          "number" => 42,
          "boolean" => true,
          "nil" => nil,
          "array" => [1, 2, 3],
          "nested" => %{"deep" => "value"}
        }}
      ]

      for original <- test_cases do
        # Encrypt
        encrypt_conn = conn(:post, "/encrypt", original) |> put_req_header("content-type", "application/json")
        encrypt_conn = Router.call(encrypt_conn, @opts)
        assert encrypt_conn.status == 200
        encrypted = Jason.decode!(encrypt_conn.resp_body)

        # Decrypt
        decrypt_conn = conn(:post, "/decrypt", encrypted) |> put_req_header("content-type", "application/json")
        decrypt_conn = Router.call(decrypt_conn, @opts)
        assert decrypt_conn.status == 200
        decrypted = Jason.decode!(decrypt_conn.resp_body)

        # JSON preserves string keys
        assert decrypted == original, "Round-trip failed for: #{inspect(original)}"
      end
    end

    test "sign -> verify flow with different data" do
      test_cases = [
        %{simple: "string"},
        %{number: 42},
        %{boolean: true},
        %{nil_value: nil},
        %{array: [1, 2, 3]},
        %{nested: %{data: "value"}},
        %{mixed: %{
          string: "test",
          number: 42,
          boolean: true,
          nil: nil,
          array: [1, 2, 3],
          nested: %{deep: "value"}
        }},
        %{}
      ]

      for data <- test_cases do
        # Sign
        sign_conn = conn(:post, "/sign", data) |> put_req_header("content-type", "application/json")
        sign_conn = Router.call(sign_conn, @opts)
        assert sign_conn.status == 200
        signed = Jason.decode!(sign_conn.resp_body)

        # Verify
        payload = %{signature: signed["signature"], data: data}
        verify_conn = conn(:post, "/verify", payload) |> put_req_header("content-type", "application/json")
        verify_conn = Router.call(verify_conn, @opts)

        assert verify_conn.status == 204,
               "Verification failed for: #{inspect(data)}"
      end
    end
  end
end
