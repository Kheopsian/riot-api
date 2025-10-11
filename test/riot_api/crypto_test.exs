defmodule RiotApi.CryptoTest do
  use ExUnit.Case, async: true

  alias RiotApi.Crypto

  describe "encrypt_payload/1" do
    test "encrypts a payload with simple values" do
      payload = %{name: "John", age: 30, active: true}
      encrypted = Crypto.encrypt_payload(payload)

      assert is_map(encrypted)
      assert encrypted.name != "John"
      assert encrypted.age != 30
      assert encrypted.active != true

      # Check that values are base64 encoded strings
      assert is_binary(encrypted.name)
      assert is_binary(encrypted.age)
      assert is_binary(encrypted.active)
    end

    test "encrypts a payload with complex values" do
      payload = %{
        user: %{name: "John", email: "john@example.com"},
        preferences: [1, 2, 3],
        metadata: nil
      }
      encrypted = Crypto.encrypt_payload(payload)

      assert is_map(encrypted)
      assert is_binary(encrypted.user)
      assert is_binary(encrypted.preferences)
      assert is_binary(encrypted.metadata)
    end

    test "encrypts an empty payload" do
      payload = %{}
      encrypted = Crypto.encrypt_payload(payload)

      assert encrypted == %{}
    end

    test "raises an error if the payload is not a map" do
      assert_raise FunctionClauseError, fn ->
        Crypto.encrypt_payload("not a map")
      end

      assert_raise FunctionClauseError, fn ->
        Crypto.encrypt_payload([1, 2, 3])
      end

      assert_raise FunctionClauseError, fn ->
        Crypto.encrypt_payload(nil)
      end
    end
  end

  describe "decrypt_payload/1" do
    test "decrypts a previously encrypted payload" do
      original = %{name: "John", age: 30, active: true}
      encrypted = Crypto.encrypt_payload(original)
      decrypted = Crypto.decrypt_payload(encrypted)

      assert decrypted == original
    end

    test "decrypts a payload with complex values" do
      original = %{
        user: %{name: "John", email: "john@example.com"},
        preferences: [1, 2, 3],
        metadata: nil
      }
      encrypted = Crypto.encrypt_payload(original)
      decrypted = Crypto.decrypt_payload(encrypted)

      # Top-level keys remain atoms,
      # but nested maps are converted to strings by JSON
      expected = %{
        user: %{"name" => "John", "email" => "john@example.com"},
        preferences: [1, 2, 3],
        metadata: nil
      }
      assert decrypted == expected
    end

    test "preserves non-binary values in the payload" do
      # Simulate a partially encrypted payload with string keys
      partially_encrypted = %{
        "encrypted_value" => Base.encode64(Jason.encode!("will_be_encrypted")),
        "already_number" => 42,
        "already_boolean" => true,
        "already_nil" => nil
      }

      decrypted = Crypto.decrypt_payload(partially_encrypted)

      assert decrypted["encrypted_value"] == "will_be_encrypted"
      assert decrypted["already_number"] == 42
      assert decrypted["already_boolean"] == true
      assert decrypted["already_nil"] == nil
    end

    test "decrypts an empty payload" do
      payload = %{}
      decrypted = Crypto.decrypt_payload(payload)

      assert decrypted == %{}
    end

    test "handles invalid non-binary values" do
      payload = %{
        valid_binary: Base.encode64(Jason.encode!("valid")),
        invalid_binary: "not_base64_@"
      }

      decrypted = Crypto.decrypt_payload(payload)

      assert decrypted.valid_binary == "valid"
      assert decrypted.invalid_binary == "not_base64_@"
    end

    test "raises an error if the payload is not a map" do
      assert_raise FunctionClauseError, fn ->
        Crypto.decrypt_payload("not a map")
      end

      assert_raise FunctionClauseError, fn ->
        Crypto.decrypt_payload([1, 2, 3])
      end

      assert_raise FunctionClauseError, fn ->
        Crypto.decrypt_payload(nil)
      end
    end
  end

  describe "sign_payload/1" do
    test "generates a signature for a payload" do
      payload = %{name: "John", age: 30}
      signed = Crypto.sign_payload(payload)

      assert is_map(signed)
      assert Map.has_key?(signed, :signature)
      assert is_binary(signed.signature)
      assert String.length(signed.signature) == 64  # SHA256 in hexadecimal
    end

    test "generates different signatures for different payloads" do
      payload1 = %{name: "John"}
      payload2 = %{name: "Jane"}
      signed1 = Crypto.sign_payload(payload1)
      signed2 = Crypto.sign_payload(payload2)

      assert signed1.signature != signed2.signature
    end

    test "generates the same signature for payloads with the same content but different order" do
      payload1 = %{a: 1, b: 2, c: 3}
      payload2 = %{c: 3, a: 1, b: 2}
      signed1 = Crypto.sign_payload(payload1)
      signed2 = Crypto.sign_payload(payload2)

      assert signed1.signature == signed2.signature
    end

    test "generates a signature for an empty payload" do
      payload = %{}
      signed = Crypto.sign_payload(payload)

      assert is_map(signed)
      assert Map.has_key?(signed, :signature)
      assert is_binary(signed.signature)
    end

    test "raises an error if the payload is not a map" do
      assert_raise FunctionClauseError, fn ->
        Crypto.sign_payload("not a map")
      end

      assert_raise FunctionClauseError, fn ->
        Crypto.sign_payload([1, 2, 3])
      end

      assert_raise FunctionClauseError, fn ->
        Crypto.sign_payload(nil)
      end
    end
  end

  describe "verify_payload/1" do
    test "verifies a valid signed payload" do
      data = %{name: "John", age: 30}
      signed = Crypto.sign_payload(data)
      payload = %{signature: signed.signature, data: data}

      # Verification succeeds because we added support for atom keys
      assert Crypto.verify_payload(payload) == true
    end

    test "verifies a valid signed payload with string keys" do
      data = %{"name" => "John", "age" => 30}
      signed = Crypto.sign_payload(data)
      payload = %{"signature" => signed.signature, "data" => data}

      assert Crypto.verify_payload(payload) == true
    end

    test "rejects a payload with an invalid signature" do
      data = %{name: "John", age: 30}
      payload = %{signature: "invalid_signature", data: data}

      assert Crypto.verify_payload(payload) == false
    end

    test "rejects a payload with modified data" do
      original_data = %{name: "John", age: 30}
      signed = Crypto.sign_payload(original_data)

      modified_data = %{name: "John", age: 31}
      payload = %{signature: signed.signature, data: modified_data}

      assert Crypto.verify_payload(payload) == false
    end

    test "rejects a payload with invalid structure" do
      # Incorrect structure - no "signature" key
      payload1 = %{data: %{name: "John"}}
      assert Crypto.verify_payload(payload1) == false

      # Incorrect structure - no "data" key
      payload2 = %{signature: "some_signature"}
      assert Crypto.verify_payload(payload2) == false

      # Incorrect structure - data is not a map
      payload3 = %{signature: "some_signature", data: "not a map"}
      assert Crypto.verify_payload(payload3) == false

      # Completely incorrect structure
      payload4 = %{wrong: "structure"}
      assert Crypto.verify_payload(payload4) == false

      # Not a map at all
      assert Crypto.verify_payload("not a map") == false
      assert Crypto.verify_payload(nil) == false
      assert Crypto.verify_payload([1, 2, 3]) == false
    end

    test "verifies a payload with complex data" do
      data = %{
        user: %{name: "John", email: "john@example.com"},
        preferences: [1, 2, 3],
        metadata: nil
      }
      signed = Crypto.sign_payload(data)
      payload = %{signature: signed.signature, data: data}

      # Verification succeeds because we added support for atom keys
      assert Crypto.verify_payload(payload) == true
    end

    test "verifies a payload with complex data and string keys" do
      data = %{
        "user" => %{"name" => "John", "email" => "john@example.com"},
        "preferences" => [1, 2, 3],
        "metadata" => nil
      }
      signed = Crypto.sign_payload(data)
      payload = %{"signature" => signed.signature, "data" => data}

      assert Crypto.verify_payload(payload) == true
    end

    test "verifies an empty payload" do
      data = %{}
      signed = Crypto.sign_payload(data)
      payload = %{"signature" => signed.signature, "data" => data}

      assert Crypto.verify_payload(payload) == true
    end
  end
end
