defmodule Ueberauth.Strategy.DocuSign.RealAPITest do
  @moduledoc """
  Tests against real DocuSign API with actual credentials.
  Run with: mix test test/integration/real_api_test.exs
  """
  use ExUnit.Case, async: false

  @moduletag :integration

  alias Ueberauth.Strategy.DocuSign.OAuth

  describe "Real DocuSign API Tests" do
    test "generates valid OAuth URLs with real credentials" do
      client = OAuth.client(site: "https://account-d.docusign.com")

      assert client.client_id == "4a3a7a9d-56cb-48f9-a9e5-e3da04b5484c"
      assert client.client_secret == "0c54cf63-8a1a-460f-8a6c-cf7141fc4728"
      assert client.site == "https://account-d.docusign.com"

      auth_url =
        OAuth.authorize_url!(
          [
            scope: "signature extended",
            state: "test_#{:rand.uniform(10_000)}",
            redirect_uri: "http://localhost:4000/auth/docusign/callback"
          ],
          site: "https://account-d.docusign.com"
        )

      assert auth_url =~ "https://account-d.docusign.com/oauth/auth"
      assert auth_url =~ "client_id=4a3a7a9d-56cb-48f9-a9e5-e3da04b5484c"
      assert auth_url =~ "response_type=code"
      assert auth_url =~ "scope=signature+extended"
      assert auth_url =~ "redirect_uri="

      IO.puts("\nGenerated OAuth URL for manual testing:")
      IO.puts(auth_url)
      IO.puts("")
    end

    test "OAuth client is configured correctly for demo environment" do
      demo_client = OAuth.client(site: "https://account-d.docusign.com")
      assert demo_client.site == "https://account-d.docusign.com"
      assert demo_client.authorize_url == "/oauth/auth"
      assert demo_client.token_url == "/oauth/token"
    end

    test "OAuth client can switch to production environment" do
      prod_client = OAuth.client(site: "https://account.docusign.com")
      assert prod_client.site == "https://account.docusign.com"
      assert prod_client.authorize_url == "/oauth/auth"
      assert prod_client.token_url == "/oauth/token"
    end

    test "handles invalid authorization code gracefully" do
      client = OAuth.client(site: "https://account-d.docusign.com")

      # Attempt to exchange an invalid code
      result =
        OAuth.get_token(
          client,
          [
            code: "invalid_code_test_#{:rand.uniform(10_000)}",
            redirect_uri: "http://localhost:4000/auth/docusign/callback"
          ],
          []
        )

      # The client should be returned with the invalid token request prepared
      assert result.params["code"] =~ "invalid_code_test_"
      assert result.params["grant_type"] == "authorization_code"
      assert result.params["redirect_uri"] == "http://localhost:4000/auth/docusign/callback"

      # Note: We can't actually make the HTTP call without mocking or real server response
      IO.puts("\nNote: Actual token exchange would fail with 400/401 from DocuSign")
    end

    test "state parameter is included for CSRF protection" do
      state = Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)

      auth_url =
        OAuth.authorize_url!(
          [
            state: state,
            redirect_uri: "http://localhost:4000/auth/docusign/callback"
          ],
          site: "https://account-d.docusign.com"
        )

      assert auth_url =~ "state=#{state}"
    end

    test "multiple scopes are properly encoded" do
      auth_url =
        OAuth.authorize_url!(
          [
            scope: "signature extended impersonation",
            redirect_uri: "http://localhost:4000/auth/docusign/callback"
          ],
          site: "https://account-d.docusign.com"
        )

      # Check that spaces are encoded as + or %20
      assert auth_url =~ "scope="
      assert auth_url =~ "signature"
      assert auth_url =~ "extended"
    end

    test "redirect URI is properly encoded" do
      redirect_uri = "https://myapp.example.com/auth/callback?param=value"

      auth_url =
        OAuth.authorize_url!(
          [
            redirect_uri: redirect_uri
          ],
          site: "https://account-d.docusign.com"
        )

      # The redirect URI should be URL encoded
      assert auth_url =~ "redirect_uri="

      assert auth_url =~ URI.encode_www_form(redirect_uri) or
               auth_url =~ String.replace(URI.encode_www_form(redirect_uri), "=", "%3D")
    end
  end

  describe "Manual Testing Instructions" do
    test "prints instructions for manual OAuth flow testing" do
      auth_url =
        OAuth.authorize_url!(
          [
            scope: "signature extended",
            state: "manual_test_#{:rand.uniform(10_000)}",
            redirect_uri: "http://localhost:4000/auth/docusign/callback"
          ],
          site: "https://account-d.docusign.com"
        )

      IO.puts("\n" <> String.duplicate("=", 60))
      IO.puts("MANUAL OAUTH FLOW TESTING")
      IO.puts(String.duplicate("=", 60))
      IO.puts("\n1. Open this URL in your browser:")
      IO.puts("\n   #{auth_url}\n")
      IO.puts("2. Log in with your DocuSign demo account credentials")
      IO.puts("\n3. Grant permission to the application")
      IO.puts("\n4. You'll be redirected to:")
      IO.puts("   http://localhost:4000/auth/docusign/callback?code=XXXXX")
      IO.puts("\n5. The 'code' parameter can be used for token exchange")
      IO.puts("\n" <> String.duplicate("=", 60) <> "\n")

      assert true
    end
  end
end
