defmodule RiotApi.RouterTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import TestHelpers

  alias RiotApi.Router

  @opts Router.init([])

  describe "POST /encrypt" do
    test "encrypts a simple payload" do
      payload = %{name: "John", age: 30}
      {status, response} = http_encrypt(payload)

      assert status == 200
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
      {status, response} = http_encrypt(payload)

      assert status == 200
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
      {status, response} = http_encrypt(%{})

      assert status == 200
      assert response == %{}
    end

    test "returns an error for invalid JSON" do
      conn = http_conn(:post, "/encrypt", "invalid json")

      # The JSON parser raises an exception for invalid JSON
      assert_raise Plug.Parsers.ParseError, fn ->
        Router.call(conn, @opts)
      end
    end
  end

  describe "POST /decrypt" do
    test "decrypts a previously encrypted payload" do
      original = %{name: "John", age: 30}
      {200, encrypted} = http_encrypt(original)
      {status, response} = http_decrypt(encrypted)

      assert status == 200
      # Atom keys become strings after decryption
      assert response == %{"name" => "John", "age" => 30}
    end

    test "decrypts a partially encrypted payload" do
      # Simulate a payload with already encrypted values and non-binary values
      payload = %{
        encrypted_value: Base.encode64(Jason.encode!("test")),
        already_number: 42,
        already_boolean: true,
        already_nil: nil
      }

      {status, response} = http_decrypt(payload)

      assert status == 200
      assert response["encrypted_value"] == "test"
      assert response["already_number"] == 42
      assert response["already_boolean"] == true
      assert response["already_nil"] == nil
    end

    test "decrypts an empty payload" do
      {status, response} = http_decrypt(%{})

      assert status == 200
      assert response == %{}
    end

    test "returns an error for invalid JSON" do
      conn = http_conn(:post, "/decrypt", "invalid json")

      # The JSON parser raises an exception for invalid JSON
      assert_raise Plug.Parsers.ParseError, fn ->
        Router.call(conn, @opts)
      end
    end
  end

  describe "POST /sign" do
    test "generates a signature for a payload" do
      payload = %{name: "John", age: 30}
      {status, response} = http_sign(payload)

      assert status == 200
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
      {status, response} = http_sign(payload)

      assert status == 200
      assert is_map(response)
      assert Map.has_key?(response, "signature")
      assert is_binary(response["signature"])
    end

    test "generates a signature for an empty payload" do
      {status, response} = http_sign(%{})

      assert status == 200
      assert is_map(response)
      assert Map.has_key?(response, "signature")
      assert is_binary(response["signature"])
    end

    test "returns an error for invalid JSON" do
      conn = http_conn(:post, "/sign", "invalid json")

      # The JSON parser raises an exception for invalid JSON
      assert_raise Plug.Parsers.ParseError, fn ->
        Router.call(conn, @opts)
      end
    end
  end

  describe "POST /verify" do
    test "verifies a valid signature" do
      data = %{name: "John", age: 30}
      {200, signed} = http_sign(data)

      status = http_verify(signed["signature"], data)

      assert status == 204
    end

    test "rejects an invalid signature" do
      data = %{name: "John", age: 30}
      status = http_verify("invalid_signature", data)

      assert status == 400
    end

    test "rejects a signature for modified data" do
      original_data = %{name: "John", age: 30}
      {200, signed} = http_sign(original_data)

      modified_data = %{name: "John", age: 31}
      status = http_verify(signed["signature"], modified_data)

      assert status == 400
    end

    test "rejects a payload with invalid structure" do
      # Incorrect structure - no "signature" key
      {conn, _} = post_and_parse("/verify", %{data: %{name: "John"}})
      assert conn.status == 400
      assert conn.resp_body == "Invalid Signature"

      # Incorrect structure - no "data" key
      {conn, _} = post_and_parse("/verify", %{signature: "some_signature"})
      assert conn.status == 400
      assert conn.resp_body == "Invalid Signature"

      # Incorrect structure - data is not a map
      {conn, _} = post_and_parse("/verify", %{signature: "some_signature", data: "not a map"})
      assert conn.status == 400
      assert conn.resp_body == "Invalid Signature"
    end

    test "returns an error for invalid JSON" do
      conn = http_conn(:post, "/verify", "invalid json")

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
end
