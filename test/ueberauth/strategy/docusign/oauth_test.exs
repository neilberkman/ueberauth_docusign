defmodule Ueberauth.Strategy.DocuSign.OAuthTest do
  use ExUnit.Case, async: false

  alias Ueberauth.Strategy.DocuSign.OAuth

  setup do
    Application.put_env(:ueberauth, OAuth,
      client_id: "test_client_id",
      client_secret: "test_client_secret"
    )

    on_exit(fn ->
      Application.delete_env(:ueberauth, OAuth)
    end)

    :ok
  end

  describe "client/1" do
    test "creates OAuth2 client with default settings" do
      client = OAuth.client()

      assert client.client_id == "test_client_id"
      assert client.client_secret == "test_client_secret"
      assert client.site == "https://account.docusign.com"
      assert client.authorize_url == "/oauth/auth"
      assert client.token_url == "/oauth/token"
    end

    test "allows overriding settings" do
      client = OAuth.client(site: "https://account-d.docusign.com")

      assert client.site == "https://account-d.docusign.com"
    end

    test "raises error when client_id is missing" do
      Application.delete_env(:ueberauth, OAuth)

      Application.put_env(:ueberauth, OAuth, client_secret: "test_secret")

      assert_raise RuntimeError, ~r/client_id missing from config/, fn ->
        OAuth.client()
      end
    end

    test "raises error when client_secret is missing" do
      Application.delete_env(:ueberauth, OAuth)
      Application.put_env(:ueberauth, OAuth, client_id: "test_id")

      assert_raise RuntimeError, ~r/client_secret missing from config/, fn ->
        OAuth.client()
      end
    end

    test "raises error when config is not a keyword list" do
      Application.delete_env(:ueberauth, OAuth)
      Application.put_env(:ueberauth, OAuth, "invalid")

      assert_raise RuntimeError, ~r/is not a keyword list/, fn ->
        OAuth.client()
      end
    end
  end

  describe "authorize_url!/2" do
    test "generates authorization URL" do
      url = OAuth.authorize_url!()

      assert url =~ "https://account.docusign.com/oauth/auth"
      assert url =~ "client_id=test_client_id"
    end

    test "includes custom parameters" do
      url = OAuth.authorize_url!(scope: "signature extended", state: "test_state")

      assert url =~ "scope=signature+extended"
      assert url =~ "state=test_state"
    end

    test "uses custom site when provided" do
      url = OAuth.authorize_url!([], site: "https://account-d.docusign.com")

      assert url =~ "https://account-d.docusign.com/oauth/auth"
    end
  end

  describe "get_access_token/2" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "successfully exchanges code for token", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        assert conn.req_headers
               |> Enum.any?(fn {k, v} -> k == "accept" && v == "application/json" end)

        body = %{
          "access_token" => "test_access_token",
          "expires_in" => 28_800,
          "refresh_token" => "test_refresh_token",
          "scope" => "signature",
          "token_type" => "Bearer"
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(body))
      end)

      opts = [site: "http://localhost:#{bypass.port}"]
      {:ok, token} = OAuth.get_access_token([code: "test_code"], opts)

      assert token.access_token == "test_access_token"
      assert token.refresh_token == "test_refresh_token"
      assert token.token_type == "Bearer"
    end

    test "handles 401 unauthorized response", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(401, Jason.encode!(%{"error" => "invalid_grant"}))
      end)

      opts = [site: "http://localhost:#{bypass.port}"]
      {:error, error} = OAuth.get_access_token([code: "bad_code"], opts)

      assert error.reason == "unauthorized"
    end

    test "handles error in response body", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        body = %{
          "error" => "invalid_request",
          "error_description" => "Invalid authorization code"
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(body))
      end)

      opts = [site: "http://localhost:#{bypass.port}"]
      {:error, error} = OAuth.get_access_token([code: "invalid"], opts)

      assert error.reason == "Invalid authorization code"
    end

    test "handles network errors", %{bypass: bypass} do
      Bypass.down(bypass)

      opts = [site: "http://localhost:#{bypass.port}"]
      {:error, error} = OAuth.get_access_token([code: "test_code"], opts)

      assert (is_atom(error.reason) and error.reason == :econnrefused) ||
               (is_binary(error.reason) &&
                  (error.reason =~ "closed" || error.reason =~ "econnrefused"))
    end
  end

  describe "get/4" do
    setup do
      bypass = Bypass.open()

      token = %OAuth2.AccessToken{
        access_token: "test_token",
        token_type: "Bearer"
      }

      {:ok, bypass: bypass, token: token}
    end

    test "makes authenticated GET request", %{bypass: bypass, token: token} do
      Bypass.expect_once(bypass, "GET", "/api/test", fn conn ->
        assert conn.req_headers
               |> Enum.any?(fn {k, v} ->
                 k == "authorization" && v == "Bearer test_token"
               end)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"result" => "success"}))
      end)

      opts = [site: "http://localhost:#{bypass.port}"]
      {:ok, response} = OAuth.get(token, "http://localhost:#{bypass.port}/api/test", [], opts)

      assert response.body == %{"result" => "success"}
    end

    test "includes custom headers", %{bypass: bypass, token: token} do
      Bypass.expect_once(bypass, "GET", "/api/test", fn conn ->
        assert conn.req_headers
               |> Enum.any?(fn {k, v} ->
                 k == "x-custom-header" && v == "custom-value"
               end)

        conn
        |> Plug.Conn.resp(200, Jason.encode!(%{}))
      end)

      headers = [{"X-Custom-Header", "custom-value"}]
      opts = [site: "http://localhost:#{bypass.port}"]
      OAuth.get(token, "http://localhost:#{bypass.port}/api/test", headers, opts)
    end
  end
end
