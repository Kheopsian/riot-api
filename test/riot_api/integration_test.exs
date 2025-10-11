defmodule RiotApi.IntegrationTest do
  use ExUnit.Case, async: true
  import TestHelpers

  alias RiotApi.Crypto

  describe "complete round-trip tests" do
    test "encrypt -> decrypt = original for all data types" do
      test_cases = all_payloads() ++ [very_complex_payload()]

      for original <- test_cases do
        # Test via the Crypto module directly
        encrypted = Crypto.encrypt_payload(original)
        decrypted = Crypto.decrypt_payload(encrypted)
        assert decrypted == original,
               "Crypto round-trip failed for: #{inspect(original)}"

        # Test via HTTP endpoints
        decrypted_http = encrypt_decrypt_roundtrip(original)
        assert decrypted_http == original,
               "HTTP round-trip failed for: #{inspect(original)}"
      end
    end

    test "sign -> verify = true for all data" do
      test_cases = all_payloads() ++ [
        %{
          "complex" => %{
            "user" => %{"name" => "John", "email" => "john@example.com"},
            "preferences" => [1, 2, 3],
            "metadata" => nil,
            "nested" => %{
              "level1" => %{
                "level2" => %{
                  "level3" => "deep value"
                }
              }
            }
          }
        }
      ]

      for data <- test_cases do
        # Test via the Crypto module directly
        signed = Crypto.sign_payload(data)
        payload = %{signature: signed.signature, data: data}
        assert Crypto.verify_payload(payload) == true,
               "Crypto verification failed for: #{inspect(data)}"

        # Test via HTTP endpoints
        {status, _signature} = sign_verify_roundtrip(data)
        assert status == 204,
               "HTTP verification failed for: #{inspect(data)}"
      end
    end

    test "complete flow: encrypt -> sign -> verify -> decrypt" do
      test_cases = [
        %{"simple" => "test"},
        %{"number" => 42},
        very_complex_payload()
      ]

      for original <- test_cases do
        # Step 1: Encrypt
        {200, encrypted} = http_encrypt(original)

        # Step 2: Sign
        {200, signed} = http_sign(encrypted)

        # Step 3: Verify
        status = http_verify(signed["signature"], encrypted)
        assert status == 204

        # Step 4: Decrypt
        {200, decrypted} = http_decrypt(encrypted)

        # Final verification
        assert decrypted == original,
               "Complete flow failed for: #{inspect(original)}"
      end
    end

  end

  describe "security and integrity tests" do
    test "signature changes if data is modified" do
      original = %{"user" => "John", "age" => 30}

      # Sign the original data
      {200, signed} = http_sign(original)

      # Modify the data in different ways and verify that the signature is invalid
      modifications = [
        %{"user" => "John", "age" => 31},  # Change a value
        %{"user" => "Jane", "age" => 30},  # Change another value
        %{"user" => "John", "age" => 30, "extra" => "field"},  # Add a field
        %{"user" => "John"},  # Remove a field
        %{"age" => 30, "user" => "John"},  # Change key order (should not change signature)
        %{"user" => "john", "age" => 30},  # Change case
        %{"user" => "John ", "age" => 30}  # Add a space
      ]

      for modified_data <- modifications do
        status = http_verify(signed["signature"], modified_data)

        # The signature should be invalid for all modifications except order change
        if modified_data == %{"age" => 30, "user" => "John"} do
          # Order change should not affect the signature
          assert status == 204,
                 "Order change should not affect signature for: #{inspect(modified_data)}"
        else
          assert status == 400,
                 "Signature should be invalid for modified data: #{inspect(modified_data)}"
        end
      end
    end

    test "encrypted data is not directly readable" do
      original = %{
        "sensitive_data" => "password123",
        "user_info" => %{"email" => "user@example.com", "ssn" => "123-45-6789"},
        "secrets" => ["api_key_1", "api_key_2"]
      }

      # Encrypt the data
      {200, encrypted} = http_encrypt(original)

      # Verify that sensitive data is not in plain text
      refute encrypted["sensitive_data"] == "password123"
      refute encrypted["user_info"] == %{"email" => "user@example.com", "ssn" => "123-45-6789"}
      refute encrypted["secrets"] == ["api_key_1", "api_key_2"]

      # Verify that they are valid base64 strings
      assert is_binary(encrypted["sensitive_data"])
      assert is_binary(encrypted["user_info"])
      assert is_binary(encrypted["secrets"])

      # Verify that they can be decrypted to get the originals
      {200, decrypted} = http_decrypt(encrypted)
      assert decrypted == original
    end

    test "resistance to signature modification attacks" do
      data = %{"user" => "John", "transaction" => 100.50}

      # Get a valid signature
      {200, signed} = http_sign(data)
      original_signature = signed["signature"]

      # Try different signature modifications
      signature_modifications = [
        "",  # Empty signature
        "invalid",  # Invalid signature
        String.slice(original_signature, 0, String.length(original_signature) - 1),  # Truncated signature
        original_signature <> "0",  # Signature with extra character
        String.reverse(original_signature),  # Reversed signature
        String.upcase(original_signature),  # Uppercase signature
        "a" <> String.slice(original_signature, 1, String.length(original_signature) - 1),  # Modified first character
        String.slice(original_signature, 0, String.length(original_signature) - 1) <> "x"  # Modified last character
      ]

      for modified_signature <- signature_modifications do
        status = http_verify(modified_signature, data)

        # All modified signatures should be rejected
        assert status == 400
      end
    end
  end

  describe "performance and limits tests" do
    test "handles large payloads" do
      # Create a large payload with string keys
      large_payload = %{
        "array" => Enum.to_list(1..1000),
        "string" => String.duplicate("a", 10000),
        "nested" => %{
          "data" => Enum.map(1..100, fn i ->
            %{
              "id" => i,
              "name" => "item_#{i}",
              "description" => String.duplicate("description for item #{i} ", 50)
            }
          end)
        }
      }

      # Encrypt/decrypt test
      decrypted = encrypt_decrypt_roundtrip(large_payload)
      assert decrypted == large_payload

      # Signature/verification test
      {status, _signature} = sign_verify_roundtrip(large_payload)
      assert status == 204
    end
  end
end
