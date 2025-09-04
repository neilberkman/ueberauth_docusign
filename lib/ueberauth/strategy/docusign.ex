defmodule Ueberauth.Strategy.DocuSign do
  @moduledoc """
  DocuSign Strategy for Überauth.

  ## Setup

  Include the provider in your configuration for Ueberauth:

      config :ueberauth, Ueberauth,
        providers: [
          docusign: {Ueberauth.Strategy.DocuSign, []}
        ]

  Then configure your OAuth app at DocuSign and add the client credentials:

      config :ueberauth, Ueberauth.Strategy.DocuSign.OAuth,
        client_id: System.get_env("DOCUSIGN_CLIENT_ID"),
        client_secret: System.get_env("DOCUSIGN_CLIENT_SECRET")

  ## Options

  The strategy accepts the following options:

  * `oauth2_module` - The OAuth2 module to use. Defaults to `Ueberauth.Strategy.DocuSign.OAuth`
  * `default_scope` - The default scope to request. Defaults to "signature"
  * `default_user_email` - The email address for login hint
  * `environment` - The DocuSign environment ("demo" or "production"). Defaults to "production"
  * `state` - A state parameter for CSRF protection. Auto-generated if not provided
  * `prompt` - Controls the authorization prompt ("login" forces re-authentication)
  """

  use Ueberauth.Strategy,
    default_scope: "signature",
    environment: "production",
    uid_field: :sub,
    oauth2_module: Ueberauth.Strategy.DocuSign.OAuth

  alias Ueberauth.Auth.{Credentials, Extra, Info}

  @doc """
  Handles the initial request for DocuSign authentication.

  This will redirect the user to DocuSign's authorization page.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)
    environment = conn.params["environment"] || option(conn, :environment)

    params =
      [scope: scopes, response_type: "code"]
      |> with_optional(
        :login_hint,
        conn.params["login_hint"] || option(conn, :default_user_email)
      )
      |> with_optional(:prompt, conn.params["prompt"] || option(conn, :prompt))
      |> maybe_add_state_param(conn)

    module = option(conn, :oauth2_module)

    redirect!(
      conn,
      module.authorize_url!(params, site: site_for_environment(environment))
    )
  end

  @doc """
  Handles the callback from DocuSign.

  This will either set the user information if authentication was successful,
  or set error information if it failed.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    environment = conn.params["environment"] || option(conn, :environment)
    module = option(conn, :oauth2_module)
    test_site = option(conn, :test_site)
    site = test_site || site_for_environment(environment)

    token =
      module.get_access_token([code: code], site: site, test_site: test_site)

    if token_expired?(token) do
      set_errors!(conn, [
        error("token", "Token has expired")
      ])
    else
      case token do
        {:ok, token} ->
          fetch_user(conn, token, environment)

        {:error, %OAuth2.Error{reason: reason}} ->
          set_errors!(conn, [error("OAuth2", reason)])

        {:error, %OAuth2.Response{body: body, status_code: 401}} ->
          set_errors!(conn, [error("token", body["error_description"] || "unauthorized")])

        {:error, _} ->
          set_errors!(conn, [error("OAuth2", "An error occurred")])
      end
    end
  end

  def handle_callback!(%Plug.Conn{params: %{"error" => error}} = conn) do
    set_errors!(conn, [error("OAuth2", error)])
  end

  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc false
  def handle_cleanup!(conn) do
    conn
    |> put_private(:docusign_user, nil)
    |> put_private(:docusign_token, nil)
  end

  @doc """
  Fetches the uid field from the response.

  The uid is the user's unique identifier at DocuSign.
  """
  def uid(conn) do
    uid_field = option(conn, :uid_field)

    conn.private.docusign_user[to_string(uid_field)]
  end

  @doc """
  Includes the credentials from the DocuSign response.
  """
  def credentials(conn) do
    token = conn.private.docusign_token
    scopes = String.split(token.other_params["scope"] || "", " ")

    %Credentials{
      expires: !!token.expires_at,
      expires_at: token.expires_at,
      refresh_token: token.refresh_token,
      scopes: scopes,
      token: token.access_token,
      token_type: token.token_type
    }
  end

  @doc """
  Fetches the user information from the DocuSign response.
  """
  def info(conn) do
    user = conn.private.docusign_user

    %Info{
      email: user["email"],
      first_name: user["given_name"],
      image: nil,
      last_name: user["family_name"],
      name: user["name"],
      nickname: nil
    }
  end

  @doc """
  Stores all the extra information from the DocuSign response.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        accounts: conn.private[:docusign_accounts],
        token: conn.private.docusign_token,
        user: conn.private.docusign_user
      }
    }
  end

  defp fetch_user(conn, token, environment) do
    conn = put_private(conn, :docusign_token, token)

    # Fetch user info
    test_site = option(conn, :test_site)

    user_url =
      if test_site do
        "#{test_site}/oauth/userinfo"
      else
        user_info_url(environment)
      end

    case option(conn, :oauth2_module).get(
           token,
           user_url,
           [{"Authorization", "Bearer #{token.access_token}"}],
           test_site: test_site
         ) do
      {:ok, %OAuth2.Response{body: user}} ->
        # Fetch accounts info
        conn = put_private(conn, :docusign_user, user)

        case fetch_accounts(conn, token, user, environment) do
          {:ok, accounts} ->
            put_private(conn, :docusign_accounts, accounts)

          {:error, _reason} ->
            # Continue without accounts - not critical for auth
            conn
        end

      {:error, %OAuth2.Response{status_code: 401}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:error, %OAuth2.Response{body: body}} ->
        set_errors!(conn, [error("OAuth2", body["message"] || "Error fetching user")])

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp fetch_accounts(conn, token, _user, environment) do
    test_site = option(conn, :test_site)

    user_url =
      if test_site do
        "#{test_site}/oauth/userinfo"
      else
        user_info_url(environment)
      end

    case option(conn, :oauth2_module).get(
           token,
           user_url,
           [{"Authorization", "Bearer #{token.access_token}"}],
           test_site: test_site
         ) do
      {:ok, %OAuth2.Response{body: %{"accounts" => accounts}}} ->
        {:ok, accounts}

      _ ->
        {:error, "Failed to fetch accounts"}
    end
  end

  defp option(conn, key) do
    request_options = conn.assigns[:ueberauth_request_options] || []

    opts =
      case List.keyfind(request_options, __MODULE__, 0) do
        {__MODULE__, opts} -> opts
        _ -> []
      end

    Keyword.get(opts, key, Keyword.get(default_options(), key))
  end

  defp site_for_environment("demo"), do: "https://account-d.docusign.com"
  defp site_for_environment(_), do: "https://account.docusign.com"

  defp user_info_url("demo"), do: "https://account-d.docusign.com/oauth/userinfo"
  defp user_info_url(_), do: "https://account.docusign.com/oauth/userinfo"

  defp with_optional(opts, _key, nil), do: opts
  defp with_optional(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_add_state_param(opts, conn) do
    state = conn.params["state"] || option(conn, :state)

    if state do
      Keyword.put(opts, :state, state)
    else
      opts
    end
  end

  defp token_expired?(nil), do: true

  defp token_expired?({:ok, %OAuth2.AccessToken{} = token}) do
    if token.expires_at do
      token.expires_at < System.system_time(:second)
    else
      false
    end
  end

  defp token_expired?(_), do: false
end
