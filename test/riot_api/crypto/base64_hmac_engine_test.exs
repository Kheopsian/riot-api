defmodule RiotApi.Crypto.Base64HmacEngineTest do
  use ExUnit.Case, async: true

  alias RiotApi.Crypto.Base64HmacEngine

  describe "encrypt/1" do
    test "encrypts a string" do
      original = "test string"
      encrypted = Base64HmacEngine.encrypt(original)

      assert is_binary(encrypted)
      assert encrypted != original
      # The base64 encoding of "test string" is "dGVzdCBzdHJpbmc="
      # but it's surrounded by JSON quotes, so we just check that it's base64
      assert Base.decode64(encrypted) != :error
    end

    test "encrypts a number" do
      original = 42
      encrypted = Base64HmacEngine.encrypt(original)

      assert is_binary(encrypted)
      assert encrypted != "42"
      assert String.contains?(encrypted, "NDI=")
    end

    test "encrypts a boolean" do
      original = true
      encrypted = Base64HmacEngine.encrypt(original)

      assert is_binary(encrypted)
      assert encrypted != "true"
      assert String.contains?(encrypted, "dHJ1ZQ==")
    end

    test "encrypts nil" do
      original = nil
      encrypted = Base64HmacEngine.encrypt(original)

      assert is_binary(encrypted)
      assert encrypted != "null"
      assert String.contains?(encrypted, "bnVsbA==")
    end

    test "encrypts a list" do
      original = [1, 2, 3]
      encrypted = Base64HmacEngine.encrypt(original)

      assert is_binary(encrypted)
      assert encrypted != "[1,2,3]"
      assert String.contains?(encrypted, "WzEsMiwzXQ==")
    end

    test "encrypts a map" do
      original = %{key: "value"}
      encrypted = Base64HmacEngine.encrypt(original)

      assert is_binary(encrypted)
      assert encrypted != "{\"key\":\"value\"}"
      assert String.contains?(encrypted, "eyJrZXkiOiJ2YWx1ZSJ9")
    end
  end

  describe "decrypt/1" do
    test "decrypts a previously encrypted string" do
      original = "test string"
      encrypted = Base64HmacEngine.encrypt(original)
      decrypted = Base64HmacEngine.decrypt(encrypted)

      assert decrypted == original
    end

    test "decrypts a previously encrypted number" do
      original = 42
      encrypted = Base64HmacEngine.encrypt(original)
      decrypted = Base64HmacEngine.decrypt(encrypted)

      assert decrypted == original
    end

    test "decrypts a previously encrypted boolean" do
      original = true
      encrypted = Base64HmacEngine.encrypt(original)
      decrypted = Base64HmacEngine.decrypt(encrypted)

      assert decrypted == original
    end

    test "decrypts a previously encrypted nil" do
      original = nil
      encrypted = Base64HmacEngine.encrypt(original)
      decrypted = Base64HmacEngine.decrypt(encrypted)

      assert decrypted == original
    end

    test "decrypts a previously encrypted list" do
      original = [1, 2, 3]
      encrypted = Base64HmacEngine.encrypt(original)
      decrypted = Base64HmacEngine.decrypt(encrypted)

      assert decrypted == original
    end

    test "decrypts a previously encrypted map" do
      original = %{key: "value"}
      encrypted = Base64HmacEngine.encrypt(original)
      decrypted = Base64HmacEngine.decrypt(encrypted)

      # Decryption returns a map with string keys
      assert decrypted == %{"key" => "value"}
    end

    test "returns the original value if it's not valid base64" do
      invalid_base64 = "not_base64_@"
      result = Base64HmacEngine.decrypt(invalid_base64)

      assert result == invalid_base64
    end

    test "returns the decoded value if it's not valid JSON" do
      # "hello" in base64
      base64_string = "aGVsbG8="
      result = Base64HmacEngine.decrypt(base64_string)

      assert result == "hello"
    end
  end

  describe "sign/1" do
    test "generates a signature for a simple map" do
      data = %{key: "value"}
      signature = Base64HmacEngine.sign(data)

      assert is_binary(signature)
      assert String.length(signature) == 64  # SHA256 in hexadecimal
    end

    test "generates identical signatures for identical data" do
      data = %{key: "value"}
      signature1 = Base64HmacEngine.sign(data)
      signature2 = Base64HmacEngine.sign(data)

      assert signature1 == signature2
    end

    test "generates different signatures for different data" do
      data1 = %{key: "value1"}
      data2 = %{key: "value2"}
      signature1 = Base64HmacEngine.sign(data1)
      signature2 = Base64HmacEngine.sign(data2)

      assert signature1 != signature2
    end

    test "generates the same signature for maps with the same content but different order" do
      data1 = %{a: 1, b: 2, c: 3}
      data2 = %{c: 3, a: 1, b: 2}
      signature1 = Base64HmacEngine.sign(data1)
      signature2 = Base64HmacEngine.sign(data2)

      assert signature1 == signature2
    end

    test "generates different signatures for maps with different keys" do
      data1 = %{a: 1, b: 2}
      data2 = %{a: 1, c: 2}
      signature1 = Base64HmacEngine.sign(data1)
      signature2 = Base64HmacEngine.sign(data2)

      assert signature1 != signature2
    end
  end

  describe "verify/2" do
    test "verifies a valid signature" do
      data = %{key: "value"}
      signature = Base64HmacEngine.sign(data)

      assert Base64HmacEngine.verify(data, signature) == true
    end

    test "rejects an invalid signature" do
      data = %{key: "value"}
      invalid_signature = "invalid_signature"

      assert Base64HmacEngine.verify(data, invalid_signature) == false
    end

    test "rejects a signature for modified data" do
      original_data = %{key: "value"}
      signature = Base64HmacEngine.sign(original_data)

      modified_data = %{key: "modified_value"}

      assert Base64HmacEngine.verify(modified_data, signature) == false
    end

    test "rejects a signature for data with an extra key" do
      original_data = %{key: "value"}
      signature = Base64HmacEngine.sign(original_data)

      modified_data = %{key: "value", extra: "field"}

      assert Base64HmacEngine.verify(modified_data, signature) == false
    end

    test "rejects a signature for data with a missing key" do
      original_data = %{key: "value", extra: "field"}
      signature = Base64HmacEngine.sign(original_data)

      modified_data = %{key: "value"}

      assert Base64HmacEngine.verify(modified_data, signature) == false
    end
  end

  describe "round-trip tests" do
    test "encrypt -> decrypt = original for different data types" do
      test_cases = [
        "simple string",
        "",
        42,
        0,
        -1,
        3.14,
        true,
        false,
        nil,
        [1, 2, 3]
      ]

      for original <- test_cases do
        encrypted = Base64HmacEngine.encrypt(original)
        decrypted = Base64HmacEngine.decrypt(encrypted)

        assert decrypted == original, "Round-trip failed for: #{inspect(original)}"
      end
    end

    test "encrypt -> decrypt for maps (with key conversion)" do
      test_cases = [
        %{key: "value"},
        %{nested: %{data: "value"}},
        %{array: [1, 2, 3]}
      ]

      for original <- test_cases do
        encrypted = Base64HmacEngine.encrypt(original)
        decrypted = Base64HmacEngine.decrypt(encrypted)

        # For maps, keys become strings after decryption
        expected = convert_keys_to_strings(original)
        assert decrypted == expected, "Round-trip failed for: #{inspect(original)}"
      end
    end

    defp convert_keys_to_strings(map) when is_map(map) do
      for {key, value} <- map, into: %{} do
        string_key = if is_atom(key), do: Atom.to_string(key), else: key
        {string_key, convert_keys_to_strings(value)}
      end
    end

    defp convert_keys_to_strings(list) when is_list(list) do
      Enum.map(list, &convert_keys_to_strings/1)
    end

    defp convert_keys_to_strings(value), do: value
  end
end
