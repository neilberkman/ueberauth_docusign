defmodule Ueberauth.Strategy.DocuSignTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias Ueberauth.Failure.Error
  alias Ueberauth.Strategy.DocuSign
  alias Ueberauth.Strategy.DocuSign.OAuth

  setup do
    Application.put_env(:ueberauth, Ueberauth,
      providers: [
        docusign: {DocuSign, [environment: "demo"]}
      ]
    )

    Application.put_env(:ueberauth, OAuth,
      client_id: "test_client_id",
      client_secret: "test_client_secret"
    )

    on_exit(fn ->
      Application.delete_env(:ueberauth, Ueberauth)
      Application.delete_env(:ueberauth, OAuth)
    end)

    :ok
  end

  describe "handle_request!" do
    test "redirects to DocuSign authorization URL" do
      conn =
        conn(:get, "/auth/docusign", %{"environment" => "demo"})
        |> fetch_query_params()
        |> assign(:ueberauth_request_options, [
          {DocuSign, [environment: "demo"]}
        ])
        |> DocuSign.handle_request!()

      assert conn.status == 302
      location = Plug.Conn.get_resp_header(conn, "location") |> List.first()

      assert location =~ "https://account-d.docusign.com/oauth/auth"
      assert location =~ "client_id=test_client_id"
      assert location =~ "response_type=code"
      assert location =~ "scope=signature"
    end

    test "includes custom scope parameter" do
      conn =
        conn(:get, "/auth/docusign", %{"scope" => "signature extended"})
        |> fetch_query_params()
        |> assign(:ueberauth_request_options, [
          {DocuSign, [environment: "demo"]}
        ])
        |> DocuSign.handle_request!()

      location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
      assert location =~ "scope=signature+extended"
    end

    test "includes login_hint when provided" do
      conn =
        conn(:get, "/auth/docusign", %{"login_hint" => "user@example.com"})
        |> fetch_query_params()
        |> assign(:ueberauth_request_options, [
          {DocuSign, [environment: "demo"]}
        ])
        |> DocuSign.handle_request!()

      location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
      assert location =~ "login_hint=user%40example.com"
    end

    test "includes prompt parameter when provided" do
      conn =
        conn(:get, "/auth/docusign", %{"prompt" => "login"})
        |> fetch_query_params()
        |> assign(:ueberauth_request_options, [
          {DocuSign, [environment: "demo"]}
        ])
        |> DocuSign.handle_request!()

      location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
      assert location =~ "prompt=login"
    end

    test "uses production environment by default" do
      conn =
        conn(:get, "/auth/docusign")
        |> fetch_query_params()
        |> assign(:ueberauth_request_options, [{DocuSign, []}])
        |> DocuSign.handle_request!()

      location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
      assert location =~ "https://account.docusign.com/oauth/auth"
    end

    test "respects environment parameter from request" do
      conn =
        conn(:get, "/auth/docusign", %{"environment" => "production"})
        |> fetch_query_params()
        |> assign(:ueberauth_request_options, [
          {DocuSign, [environment: "demo"]}
        ])
        |> DocuSign.handle_request!()

      location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
      assert location =~ "https://account.docusign.com/oauth/auth"
    end

    test "includes state parameter when provided" do
      conn =
        conn(:get, "/auth/docusign", %{"state" => "test_state_123"})
        |> fetch_query_params()
        |> assign(:ueberauth_request_options, [
          {DocuSign, [environment: "demo"]}
        ])
        |> DocuSign.handle_request!()

      location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
      assert location =~ "state=test_state_123"
    end
  end

  describe "handle_callback!" do
    setup do
      bypass = Bypass.open()

      Application.put_env(:ueberauth, OAuth,
        client_id: "test_client_id",
        client_secret: "test_client_secret"
      )

      {:ok, bypass: bypass}
    end

    test "handles successful callback with user info", %{bypass: bypass} do
      token_response = %{
        "access_token" => "test_access_token",
        "expires_in" => 28_800,
        "refresh_token" => "test_refresh_token",
        "scope" => "signature extended",
        "token_type" => "Bearer"
      }

      user_response = %{
        "accounts" => [
          %{
            "account_id" => "acc_123",
            "account_name" => "Test Account",
            "base_uri" => "https://demo.docusign.net",
            "is_default" => true
          }
        ],
        "email" => "john.doe@example.com",
        "family_name" => "Doe",
        "given_name" => "John",
        "name" => "John Doe",
        "sub" => "user_123"
      }

      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(token_response))
      end)

      Bypass.expect(bypass, "GET", "/oauth/userinfo", fn conn ->
        assert conn.req_headers
               |> Enum.any?(fn {k, v} ->
                 k == "authorization" && v == "Bearer test_access_token"
               end)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(user_response))
      end)

      opts = [
        environment: "demo",
        oauth2_module: TestOAuth,
        test_site: "http://localhost:#{bypass.port}"
      ]

      conn =
        conn(:get, "/auth/docusign/callback", %{"code" => "test_code", "environment" => "demo"})
        |> fetch_query_params()
        |> assign(:ueberauth_request_options, [{DocuSign, opts}])
        |> setup_mock_oauth(bypass.port)
        |> DocuSign.handle_callback!()

      assert conn.private.docusign_user["sub"] == "user_123"
      assert conn.private.docusign_user["email"] == "john.doe@example.com"
      assert conn.private.docusign_token.access_token == "test_access_token"
      assert is_list(conn.private[:docusign_accounts])
    end

    test "handles callback with error parameter", %{bypass: _bypass} do
      conn =
        conn(:get, "/auth/docusign/callback", %{"error" => "access_denied"})
        |> fetch_query_params()
        |> assign(:ueberauth_failure, nil)
        |> assign(:ueberauth_request_options, [{DocuSign, []}])
        |> DocuSign.handle_callback!()

      failure = conn.assigns.ueberauth_failure

      assert failure.errors == [
               %Error{message: "access_denied", message_key: "OAuth2"}
             ]
    end

    test "handles callback without code parameter", %{bypass: _bypass} do
      conn =
        conn(:get, "/auth/docusign/callback", %{})
        |> fetch_query_params()
        |> assign(:ueberauth_failure, nil)
        |> assign(:ueberauth_request_options, [{DocuSign, []}])
        |> DocuSign.handle_callback!()

      failure = conn.assigns.ueberauth_failure

      assert failure.errors == [
               %Error{message: "No code received", message_key: "missing_code"}
             ]
    end

    test "handles token exchange failure", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(401, Jason.encode!(%{"error" => "invalid_grant"}))
      end)

      opts = [
        environment: "demo",
        oauth2_module: TestOAuth,
        test_site: "http://localhost:#{bypass.port}"
      ]

      conn =
        conn(:get, "/auth/docusign/callback", %{"code" => "bad_code"})
        |> fetch_query_params()
        |> assign(:ueberauth_failure, nil)
        |> assign(:ueberauth_request_options, [{DocuSign, opts}])
        |> setup_mock_oauth(bypass.port)
        |> DocuSign.handle_callback!()

      failure = conn.assigns.ueberauth_failure
      assert not Enum.empty?(failure.errors)
    end

    test "handles user info fetch failure", %{bypass: bypass} do
      token_response = %{
        "access_token" => "test_access_token",
        "expires_in" => 28_800,
        "token_type" => "Bearer"
      }

      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(token_response))
      end)

      Bypass.expect_once(bypass, "GET", "/oauth/userinfo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(401, Jason.encode!(%{"error" => "invalid_token"}))
      end)

      opts = [
        environment: "demo",
        oauth2_module: TestOAuth,
        test_site: "http://localhost:#{bypass.port}"
      ]

      conn =
        conn(:get, "/auth/docusign/callback", %{"code" => "test_code"})
        |> fetch_query_params()
        |> assign(:ueberauth_failure, nil)
        |> assign(:ueberauth_request_options, [{DocuSign, opts}])
        |> setup_mock_oauth(bypass.port)
        |> DocuSign.handle_callback!()

      failure = conn.assigns.ueberauth_failure
      assert not Enum.empty?(failure.errors)
    end
  end

  describe "handle_cleanup!" do
    test "clears private DocuSign data" do
      conn =
        conn(:get, "/")
        |> Map.put(:private, %{
          docusign_token: %{access_token: "token"},
          docusign_user: %{"sub" => "123"},
          other_data: "preserved"
        })
        |> DocuSign.handle_cleanup!()

      assert conn.private.docusign_user == nil
      assert conn.private.docusign_token == nil
      assert conn.private.other_data == "preserved"
    end
  end

  describe "uid/1" do
    test "extracts uid from user data" do
      conn =
        conn(:get, "/")
        |> assign(:ueberauth_request_options, [{DocuSign, []}])
        |> Map.put(:private, %{
          docusign_user: %{"email" => "test@example.com", "sub" => "user_123"}
        })

      assert DocuSign.uid(conn) == "user_123"
    end

    test "uses custom uid field when configured" do
      conn =
        conn(:get, "/")
        |> assign(:ueberauth_request_options, [{DocuSign, [uid_field: :email]}])
        |> Map.put(:private, %{
          docusign_user: %{"email" => "test@example.com", "sub" => "user_123"}
        })

      assert DocuSign.uid(conn) == "test@example.com"
    end
  end

  describe "credentials/1" do
    test "builds credentials from token" do
      expires_at = System.system_time(:second) + 3600

      conn =
        conn(:get, "/")
        |> Map.put(:private, %{
          docusign_token: %OAuth2.AccessToken{
            access_token: "access_123",
            expires_at: expires_at,
            other_params: %{"scope" => "signature extended"},
            refresh_token: "refresh_456",
            token_type: "Bearer"
          }
        })

      creds = DocuSign.credentials(conn)

      assert creds.token == "access_123"
      assert creds.refresh_token == "refresh_456"
      assert creds.expires == true
      assert creds.expires_at == expires_at
      assert creds.token_type == "Bearer"
      assert creds.scopes == ["signature", "extended"]
    end

    test "handles missing scope in token" do
      conn =
        conn(:get, "/")
        |> Map.put(:private, %{
          docusign_token: %OAuth2.AccessToken{
            access_token: "access_123",
            other_params: %{}
          }
        })

      creds = DocuSign.credentials(conn)
      assert creds.scopes == [""]
    end
  end

  describe "info/1" do
    test "extracts user info correctly" do
      conn =
        conn(:get, "/")
        |> Map.put(:private, %{
          docusign_user: %{
            "email" => "john.doe@example.com",
            "family_name" => "Doe",
            "given_name" => "John",
            "name" => "John Doe"
          }
        })

      info = DocuSign.info(conn)

      assert info.email == "john.doe@example.com"
      assert info.name == "John Doe"
      assert info.first_name == "John"
      assert info.last_name == "Doe"
      assert info.image == nil
      assert info.nickname == nil
    end

    test "handles missing user fields gracefully" do
      conn =
        conn(:get, "/")
        |> Map.put(:private, %{
          docusign_user: %{
            "email" => "test@example.com"
          }
        })

      info = DocuSign.info(conn)

      assert info.email == "test@example.com"
      assert info.name == nil
      assert info.first_name == nil
      assert info.last_name == nil
    end
  end

  describe "extra/1" do
    test "includes raw token, user, and accounts data" do
      conn =
        conn(:get, "/")
        |> Map.put(:private, %{
          docusign_accounts: [%{"account_id" => "acc_123"}],
          docusign_token: %{access_token: "token_123"},
          docusign_user: %{"sub" => "user_123"}
        })

      extra = DocuSign.extra(conn)

      assert extra.raw_info.token == %{access_token: "token_123"}
      assert extra.raw_info.user == %{"sub" => "user_123"}
      assert extra.raw_info.accounts == [%{"account_id" => "acc_123"}]
    end

    test "handles missing accounts data" do
      conn =
        conn(:get, "/")
        |> Map.put(:private, %{
          docusign_token: %{access_token: "token_123"},
          docusign_user: %{"sub" => "user_123"}
        })

      extra = DocuSign.extra(conn)

      assert extra.raw_info.accounts == nil
    end
  end

  # Helper functions
  defp setup_mock_oauth(conn, port) do
    # This simulates setting up the OAuth module with the bypass port
    Application.put_env(:ueberauth, OAuth,
      client_id: "test_client_id",
      client_secret: "test_client_secret",
      site: "http://localhost:#{port}"
    )

    conn
  end
end

# Test OAuth module for testing with bypass
defmodule TestOAuth do
  alias Ueberauth.Strategy.DocuSign.OAuth

  def authorize_url!(params, opts) do
    OAuth.authorize_url!(params, opts)
  end

  def get_access_token(params, opts) do
    # Override the site to use bypass
    test_site = opts[:test_site] || opts[:site]

    if test_site do
      OAuth.get_access_token(
        params,
        Keyword.put(opts, :site, test_site)
      )
    else
      OAuth.get_access_token(params, opts)
    end
  end

  def get(token, url, headers, opts \\ []) do
    # Replace the production URL with bypass URL if needed
    test_site = opts[:test_site]

    if test_site && String.contains?(url, "docusign") do
      url = String.replace(url, ~r/https?:\/\/[^\/]+/, test_site)
      OAuth.get(token, url, headers, opts)
    else
      OAuth.get(token, url, headers, opts)
    end
  end
end
