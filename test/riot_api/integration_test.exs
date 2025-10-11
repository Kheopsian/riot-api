defmodule RiotApi.IntegrationTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias RiotApi.Router
  alias RiotApi.Crypto

  @opts Router.init([])

  describe "complete round-trip tests" do
    test "encrypt -> decrypt = original for all data types" do
      test_cases = [
        # Simple maps (only maps are supported by Crypto.encrypt_payload)
        %{},
        %{"key" => "value"},
        %{"number" => 42},
        %{"boolean" => true},
        %{"nil_value" => nil},

        # Complex maps
        %{"nested" => %{"deep" => "value"}},
        %{"array" => [1, 2, 3]},
        %{"mixed" => %{
          "string" => "test",
          "number" => 42,
          "boolean" => true,
          "nil" => nil,
          "array" => [1, 2, 3],
          "nested" => %{"deep" => "value"}
        }},

        # Very complex structures
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
      ]

      for original <- test_cases do
        # Test via the Crypto module directly
        encrypted = Crypto.encrypt_payload(original)
        decrypted = Crypto.decrypt_payload(encrypted)
        assert decrypted == original,
               "Crypto round-trip failed for: #{inspect(original)}"

        # Test via HTTP endpoints
        encrypt_conn = conn(:post, "/encrypt", original)
                      |> put_req_header("content-type", "application/json")
        encrypt_conn = Router.call(encrypt_conn, @opts)
        assert encrypt_conn.status == 200
        encrypted_http = Jason.decode!(encrypt_conn.resp_body)

        decrypt_conn = conn(:post, "/decrypt", encrypted_http)
                      |> put_req_header("content-type", "application/json")
        decrypt_conn = Router.call(decrypt_conn, @opts)
        assert decrypt_conn.status == 200
        decrypted_http = Jason.decode!(decrypt_conn.resp_body)

        assert decrypted_http == original,
               "HTTP round-trip failed for: #{inspect(original)}"
      end
    end

    test "sign -> verify = true for all data" do
      test_cases = [
        %{},
        %{"simple" => "string"},
        %{"number" => 42},
        %{"boolean" => true},
        %{"nil_value" => nil},
        %{"array" => [1, 2, 3]},
        %{"nested" => %{"data" => "value"}},
        %{"mixed" => %{
          "string" => "test",
          "number" => 42,
          "boolean" => true,
          "nil" => nil,
          "array" => [1, 2, 3],
          "nested" => %{"deep" => "value"}
        }},
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
        sign_conn = conn(:post, "/sign", data)
                   |> put_req_header("content-type", "application/json")
        sign_conn = Router.call(sign_conn, @opts)
        assert sign_conn.status == 200
        signed_http = Jason.decode!(sign_conn.resp_body)

        verify_payload = %{"signature" => signed_http["signature"], "data" => data}
        verify_conn = conn(:post, "/verify", verify_payload)
                     |> put_req_header("content-type", "application/json")
        verify_conn = Router.call(verify_conn, @opts)

        assert verify_conn.status == 204,
               "HTTP verification failed for: #{inspect(data)}"
      end
    end

    test "complete flow: encrypt -> sign -> verify -> decrypt" do
      test_cases = [
        %{"simple" => "test"},
        %{"number" => 42},
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
      ]

      for original <- test_cases do
        # Step 1: Encrypt
        encrypt_conn = conn(:post, "/encrypt", original)
                      |> put_req_header("content-type", "application/json")
        encrypt_conn = Router.call(encrypt_conn, @opts)
        assert encrypt_conn.status == 200
        encrypted = Jason.decode!(encrypt_conn.resp_body)

        # Step 2: Sign
        sign_conn = conn(:post, "/sign", encrypted)
                   |> put_req_header("content-type", "application/json")
        sign_conn = Router.call(sign_conn, @opts)
        assert sign_conn.status == 200
        signed = Jason.decode!(sign_conn.resp_body)

        # Step 3: Verify
        payload = %{"signature" => signed["signature"], "data" => encrypted}
        verify_conn = conn(:post, "/verify", payload)
                     |> put_req_header("content-type", "application/json")
        verify_conn = Router.call(verify_conn, @opts)
        assert verify_conn.status == 204

        # Step 4: Decrypt
        decrypt_conn = conn(:post, "/decrypt", encrypted)
                      |> put_req_header("content-type", "application/json")
        decrypt_conn = Router.call(decrypt_conn, @opts)
        assert decrypt_conn.status == 200
        decrypted = Jason.decode!(decrypt_conn.resp_body)

        # Final verification
        assert decrypted == original,
               "Complete flow failed for: #{inspect(original)}"
      end
    end

  end

  describe "security and integrity tests" do
    test "signature changes if data is modified" do
      # Use string keys since JSON will convert them anyway
      original = %{"user" => "John", "age" => 30}

      # Sign the original data
      sign_conn = conn(:post, "/sign", original)
                 |> put_req_header("content-type", "application/json")
      sign_conn = Router.call(sign_conn, @opts)
      signed = Jason.decode!(sign_conn.resp_body)

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
        payload = %{"signature" => signed["signature"], "data" => modified_data}
        verify_conn = conn(:post, "/verify", payload)
                     |> put_req_header("content-type", "application/json")
        verify_conn = Router.call(verify_conn, @opts)

        # The signature should be invalid for all modifications except order change
        if modified_data == %{"age" => 30, "user" => "John"} do
          # Order change should not affect the signature
          assert verify_conn.status == 204,
                 "Order change should not affect signature for: #{inspect(modified_data)}"
        else
          assert verify_conn.status == 400,
                 "Signature should be invalid for modified data: #{inspect(modified_data)}"
          assert verify_conn.resp_body == "Invalid Signature"
        end
      end
    end

    test "encrypted data is not directly readable" do
      # Use string keys since JSON will convert them anyway
      original = %{
        "sensitive_data" => "password123",
        "user_info" => %{"email" => "user@example.com", "ssn" => "123-45-6789"},
        "secrets" => ["api_key_1", "api_key_2"]
      }

      # Encrypt the data
      encrypt_conn = conn(:post, "/encrypt", original)
                    |> put_req_header("content-type", "application/json")
      encrypt_conn = Router.call(encrypt_conn, @opts)
      encrypted = Jason.decode!(encrypt_conn.resp_body)

      # Verify that sensitive data is not in plain text
      refute encrypted["sensitive_data"] == "password123"
      refute encrypted["user_info"] == %{"email" => "user@example.com", "ssn" => "123-45-6789"}
      refute encrypted["secrets"] == ["api_key_1", "api_key_2"]

      # Verify that they are valid base64 strings
      assert is_binary(encrypted["sensitive_data"])
      assert is_binary(encrypted["user_info"])
      assert is_binary(encrypted["secrets"])

      # Verify that they can be decrypted to get the originals
      decrypt_conn = conn(:post, "/decrypt", encrypted)
                    |> put_req_header("content-type", "application/json")
      decrypt_conn = Router.call(decrypt_conn, @opts)
      decrypted = Jason.decode!(decrypt_conn.resp_body)

      # JSON preserves string keys
      assert decrypted == original
    end

    test "resistance to signature modification attacks" do
      # Use string keys since JSON will convert them anyway
      data = %{"user" => "John", "transaction" => 100.50}

      # Get a valid signature
      sign_conn = conn(:post, "/sign", data)
                 |> put_req_header("content-type", "application/json")
      sign_conn = Router.call(sign_conn, @opts)
      signed = Jason.decode!(sign_conn.resp_body)
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
        payload = %{"signature" => modified_signature, "data" => data}
        verify_conn = conn(:post, "/verify", payload)
                     |> put_req_header("content-type", "application/json")
        verify_conn = Router.call(verify_conn, @opts)

        # All modified signatures should be rejected
        assert verify_conn.status == 400
        assert verify_conn.resp_body == "Invalid Signature"
      end
    end
  end

  describe "performance and limits tests" do
    test "handles large payloads" do
      # Create a large payload with string keys
      large_array = Enum.to_list(1..1000)
      large_string = String.duplicate("a", 10000)
      large_nested = %{
        "data" => Enum.map(1..100, fn i ->
          %{
            "id" => i,
            "name" => "item_#{i}",
            "description" => String.duplicate("description for item #{i} ", 50)
          }
        end)
      }

      large_payload = %{
        "array" => large_array,
        "string" => large_string,
        "nested" => large_nested
      }

      # Encrypt/decrypt test
      encrypt_conn = conn(:post, "/encrypt", large_payload)
                    |> put_req_header("content-type", "application/json")
      encrypt_conn = Router.call(encrypt_conn, @opts)
      assert encrypt_conn.status == 200
      encrypted = Jason.decode!(encrypt_conn.resp_body)

      decrypt_conn = conn(:post, "/decrypt", encrypted)
                    |> put_req_header("content-type", "application/json")
      decrypt_conn = Router.call(decrypt_conn, @opts)
      assert decrypt_conn.status == 200
      decrypted = Jason.decode!(decrypt_conn.resp_body)

      # JSON preserves string keys
      assert decrypted == large_payload

      # Signature/verification test
      sign_conn = conn(:post, "/sign", large_payload)
                 |> put_req_header("content-type", "application/json")
      sign_conn = Router.call(sign_conn, @opts)
      assert sign_conn.status == 200
      signed = Jason.decode!(sign_conn.resp_body)

      payload = %{"signature" => signed["signature"], "data" => large_payload}
      verify_conn = conn(:post, "/verify", payload)
                   |> put_req_header("content-type", "application/json")
      verify_conn = Router.call(verify_conn, @opts)
      assert verify_conn.status == 204
    end
  end
end
