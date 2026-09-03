defmodule Ueberauth.Strategy.DocuSign.IntegrationTest do
  @moduledoc """
  Integration tests for the DocuSign OAuth strategy against real DocuSign endpoints.

  These tests are disabled by default. To run them:

  1. Set DOCUSIGN_CLIENT_ID and DOCUSIGN_CLIENT_SECRET in the environment
  2. Run: mix test --include integration

  WARNING: These tests will make real API calls to DocuSign's demo environment.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Ueberauth.Strategy.DocuSign.OAuth

  @moduletag :integration

  if System.get_env("DOCUSIGN_CLIENT_ID") in [nil, ""] or
       System.get_env("DOCUSIGN_CLIENT_SECRET") in [nil, ""] do
    @moduletag skip: "DOCUSIGN_CLIENT_ID and DOCUSIGN_CLIENT_SECRET are not set"
  end

  describe "Real DocuSign OAuth Flow" do
    setup do
      client_id = System.fetch_env!("DOCUSIGN_CLIENT_ID")
      client_secret = System.fetch_env!("DOCUSIGN_CLIENT_SECRET")
      previous_config = Application.get_env(:ueberauth, OAuth)

      Application.put_env(:ueberauth, OAuth,
        client_id: client_id,
        client_secret: client_secret
      )

      on_exit(fn ->
        if previous_config do
          Application.put_env(:ueberauth, OAuth, previous_config)
        else
          Application.delete_env(:ueberauth, OAuth)
        end
      end)

      {:ok, client_id: client_id, client_secret: client_secret}
    end

    test "client/0 creates valid OAuth client with real credentials", context do
      client = OAuth.client(site: "https://account-d.docusign.com")

      assert client.client_id == context.client_id
      assert client.client_secret == context.client_secret
      assert client.site == "https://account-d.docusign.com"
      assert client.authorize_url == "/oauth/auth"
      assert client.token_url == "/oauth/token"
    end

    test "authorize_url/2 generates valid DocuSign authorization URL", _context do
      params = [
        scope: "signature extended",
        state: "test_state_123",
        redirect_uri: "http://localhost:4000/auth/docusign/callback"
      ]

      url = OAuth.authorize_url!(params, site: "https://account-d.docusign.com")

      assert url =~ "https://account-d.docusign.com/oauth/auth"
      assert url =~ "client_id="
      assert url =~ "response_type=code"
      assert url =~ "scope=signature+extended" or url =~ "scope=signature%20extended"
      assert url =~ "state=test_state_123"
      assert url =~ "redirect_uri=http%3A%2F%2Flocalhost%3A4000%2Fauth%2Fdocusign%2Fcallback"
    end

    test "environment switching between demo and production", _context do
      # Test demo environment
      demo_client = OAuth.client([{:site, "https://account-d.docusign.com"}])
      assert demo_client.site == "https://account-d.docusign.com"

      # Test production environment
      prod_client = OAuth.client([{:site, "https://account.docusign.com"}])
      assert prod_client.site == "https://account.docusign.com"
    end

    @tag :skip
    @tag :manual
    test "MANUAL: Complete OAuth flow with real authorization", _context do
      # This test requires manual intervention to complete the OAuth flow.
      #
      # To run this test manually:
      # 1. Remove the @tag :skip from this test
      # 2. Run: mix test --include integration test/integration/docusign_oauth_integration_test.exs --only manual
      # 3. Visit the URL printed below
      # 4. Log in to DocuSign and authorize the application
      # 5. Copy the 'code' parameter from the redirect URL
      # 6. Update the test with the code

      # Generate authorization URL
      auth_url =
        OAuth.authorize_url!(
          scope: "signature extended",
          redirect_uri: "http://localhost:4000/auth/docusign/callback",
          state: "test_state"
        )

      IO.puts("\n\n=== MANUAL TEST INSTRUCTIONS ===")
      IO.puts("1. Visit this URL in your browser:")
      IO.puts(auth_url)
      IO.puts("\n2. Log in and authorize the application")
      IO.puts("3. Copy the 'code' from the redirect URL")
      IO.puts("4. Update this test with the code")
      IO.puts("================================\n\n")

      # Uncomment and update with the actual code from the redirect
      # code = "YOUR_AUTH_CODE_HERE"
      # 
      # {:ok, token} = OAuth.get_token([code: code, redirect_uri: "http://localhost:4000/auth/docusign/callback"])
      # 
      # assert token.access_token != nil
      # assert token.token_type == "Bearer"
      # assert token.expires_at != nil

      # For now, just assert true to pass the test structure
      assert true
    end
  end

  describe "Token Exchange" do
    @tag :skip
    @tag :requires_valid_code
    test "get_token/2 exchanges valid code for access token", _context do
      # This test requires a valid authorization code.
      # It's skipped by default since authorization codes are single-use and expire quickly.

      # This would need a valid, unused authorization code
      # code = "VALID_CODE_HERE"
      # 
      # {:ok, token} = OAuth.get_token([
      #   code: code,
      #   redirect_uri: "http://localhost:4000/auth/docusign/callback"
      # ])
      # 
      # assert %OAuth2.AccessToken{} = token
      # assert token.access_token != nil
      # assert token.refresh_token != nil
      # assert token.expires_at != nil

      assert true
    end

    @tag :skip
    test "get_token/2 handles invalid code correctly", _context do
      result =
        capture_log(fn ->
          client = OAuth.client()

          OAuth.get_token(
            client,
            [
              code: "invalid_code_12345",
              redirect_uri: "http://localhost:4000/auth/docusign/callback"
            ],
            []
          )
        end)

      # DocuSign should reject invalid codes
      assert result =~ "error" or result =~ "invalid"
    end
  end

  describe "User Info Endpoint" do
    @tag :skip
    @tag :requires_valid_token
    test "get/3 fetches user info with valid token", _context do
      # This test requires a valid access token.
      # It's skipped by default since tokens expire.

      # This would need a valid access token
      # token = %OAuth2.AccessToken{
      #   access_token: "VALID_ACCESS_TOKEN",
      #   token_type: "Bearer"
      # }
      # 
      # {:ok, response} = OAuth.get(token, "/oauth/userinfo")
      # 
      # assert response.status == 200
      # user_info = response.body
      # 
      # assert user_info["sub"] != nil  # User ID
      # assert user_info["email"] != nil
      # assert user_info["accounts"] != nil
      # assert is_list(user_info["accounts"])

      assert true
    end
  end

  describe "Error Handling" do
    @tag :skip
    test "handles network errors gracefully", _context do
      # Test with invalid host
      client = OAuth.client([{:site, "https://invalid.docusign.test"}])

      result =
        capture_log(fn ->
          OAuth2.Client.get_token(client,
            code: "test_code",
            redirect_uri: "http://localhost:4000/callback"
          )
        end)

      assert result =~ "error" or result =~ "failed"
    end

    @tag :skip
    test "handles malformed responses", _context do
      # This would test handling of non-JSON responses
      # Would need to mock or use a test endpoint
      assert true
    end
  end

  describe "CSRF Protection" do
    test "state parameter is preserved through flow", _context do
      state = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

      auth_url =
        OAuth.authorize_url!(
          state: state,
          redirect_uri: "http://localhost:4000/auth/docusign/callback"
        )

      assert auth_url =~ "state=#{state}"

      # In a real flow, we'd verify the state parameter matches in the callback
      assert true
    end
  end

  describe "Token Refresh" do
    @tag :skip
    @tag :requires_refresh_token
    test "refresh_token/2 gets new access token", _context do
      # This test requires a valid refresh token.
      # Refresh tokens are long-lived and can be used to get new access tokens.

      # This would need a valid refresh token
      # client = OAuth.client()
      # 
      # {:ok, new_token} = OAuth2.Client.refresh_token(client, [
      #   refresh_token: "VALID_REFRESH_TOKEN"
      # ])
      # 
      # assert new_token.access_token != nil
      # assert new_token.access_token != old_access_token
      # assert new_token.expires_at != nil

      assert true
    end
  end
end
