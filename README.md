[![Hex.pm](https://img.shields.io/hexpm/v/ueberauth_docusign)](https://hex.pm/packages/ueberauth_docusign)
[![Hexdocs.pm](https://img.shields.io/badge/docs-hexdocs.pm-purple)](https://hexdocs.pm/ueberauth_docusign)
[![Github.com](https://github.com/neilberkman/ueberauth_docusign/actions/workflows/elixir.yml/badge.svg)](https://github.com/neilberkman/ueberauth_docusign/actions)

# Überauth DocuSign

> DocuSign OAuth2 strategy for Überauth.

Complete OAuth2 integration for DocuSign authentication in your Elixir applications. This library enables secure user authentication and authorization through DocuSign's OAuth2 implementation, perfect for applications that need to integrate with DocuSign's eSignature APIs.

## Features

- **Full OAuth2 Support** - Complete implementation of DocuSign's OAuth2 Authorization Code flow
- **Multi-Environment** - Seamless switching between demo (sandbox) and production environments
- **Multi-Account Support** - Handle users with multiple DocuSign accounts
- **Security First** - Built-in CSRF protection via state parameter
- **Token Management** - Support for token refresh and expiration handling
- **Production Ready** - Comprehensive test suite and real API verification
- **Easy Integration** - Works seamlessly with the [docusign](https://hex.pm/packages/docusign) client library

## Installation

Add `ueberauth_docusign` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ueberauth, "~> 0.10"},
    {:ueberauth_docusign, "~> 0.1.0"},
    # Optional: For making API calls after authentication
    {:docusign, "~> 3.0"}
  ]
end
```

## Configuration

### 1. Configure Überauth

Add DocuSign to your Überauth configuration:

```elixir
# config/config.exs
config :ueberauth, Ueberauth,
  providers: [
    docusign: {Ueberauth.Strategy.DocuSign, [
      default_scope: "signature extended",
      environment: "demo"  # or "production"
    ]}
  ]
```

### 2. Configure OAuth Credentials

Add your DocuSign OAuth credentials:

```elixir
# config/runtime.exs or config/dev.exs
config :ueberauth, Ueberauth.Strategy.DocuSign.OAuth,
  client_id: System.get_env("DOCUSIGN_CLIENT_ID"),
  client_secret: System.get_env("DOCUSIGN_CLIENT_SECRET")
```

To get your credentials:

1. Go to [DocuSign Developer Center](https://developers.docusign.com)
2. Create a new integration or use an existing one
3. Copy your **Integration Key** (client_id) and **Secret Key** (client_secret)
4. Add your redirect URI: `https://yourapp.com/auth/docusign/callback`

### 3. Set Up Routes

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug Ueberauth
  end

  scope "/auth", MyAppWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    post "/:provider/callback", AuthController, :callback
  end
end
```

### 4. Implement Controller

```elixir
# lib/my_app_web/controllers/auth_controller.ex
defmodule MyAppWeb.AuthController do
  use MyAppWeb, :controller

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate: #{inspect(fails)}")
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case create_or_update_user(auth) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Successfully authenticated!")
        |> put_session(:current_user, user)
        |> configure_session(renew: true)
        |> redirect(to: "/dashboard")

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: "/")
    end
  end

  defp create_or_update_user(%Ueberauth.Auth{} = auth) do
    # Extract user information
    %{
      uid: auth.uid,
      email: auth.info.email,
      name: auth.info.name,
      token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      expires_at: auth.credentials.expires_at,
      accounts: auth.extra.raw_info.accounts
    }
    |> find_or_create_user()
  end
end
```

## Advanced Configuration

### OAuth Scopes

DocuSign supports various OAuth scopes to control access:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    docusign: {Ueberauth.Strategy.DocuSign, [
      default_scope: "signature extended impersonation"
    ]}
  ]
```

Available scopes:

- `signature` - Send and sign envelopes
- `extended` - Access additional APIs beyond signature
- `impersonation` - Act on behalf of other users (requires admin consent)

### Environment Configuration

Switch between demo (sandbox) and production environments:

```elixir
# Demo/Sandbox environment (default)
config :ueberauth, Ueberauth,
  providers: [
    docusign: {Ueberauth.Strategy.DocuSign, [environment: "demo"]}
  ]

# Production environment
config :ueberauth, Ueberauth,
  providers: [
    docusign: {Ueberauth.Strategy.DocuSign, [environment: "production"]}
  ]
```

### Request Options

You can pass additional parameters in the authorization request:

```elixir
# In your controller or view
def login(conn, _params) do
  conn
  |> redirect(to: Routes.auth_path(conn, :request, :docusign,
    scope: "signature extended",
    login_hint: "user@example.com",
    prompt: "login"  # Forces re-authentication
  ))
end
```

## Integration with DocuSign API Client

After successful authentication, use the access token with the [docusign](https://hex.pm/packages/docusign) client:

```elixir
def handle_docusign_auth(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
  # Get the default account
  account = Enum.find(auth.extra.raw_info.accounts, & &1["is_default"])

  # Create a connection for API calls
  {:ok, api_conn} = DocuSign.Connection.from_oauth_client(
    build_oauth_client(auth.credentials.token),
    account_id: account["account_id"],
    base_uri: account["base_uri"] <> "/restapi"
  )

  # Now you can make API calls
  {:ok, envelopes} = DocuSign.Api.Envelopes.envelopes_get_envelopes(
    api_conn,
    account["account_id"]
  )
end

defp build_oauth_client(access_token) do
  OAuth2.Client.new(
    token: %OAuth2.AccessToken{
      access_token: access_token,
      token_type: "Bearer"
    }
  )
end
```

## Working with Multiple Accounts

DocuSign users may have access to multiple accounts. Handle account selection:

```elixir
def handle_multiple_accounts(auth) do
  accounts = auth.extra.raw_info.accounts

  # Get the default account
  default_account = Enum.find(accounts, & &1["is_default"])

  # Or let user choose
  Enum.map(accounts, fn account ->
    %{
      id: account["account_id"],
      name: account["account_name"],
      base_uri: account["base_uri"],
      is_default: account["is_default"]
    }
  end)
end
```

## Token Refresh

Handle token expiration and refresh:

```elixir
def refresh_token(refresh_token) do
  client = OAuth2.Client.new(
    strategy: OAuth2.Strategy.Refresh,
    client_id: Application.fetch_env!(:ueberauth, Ueberauth.Strategy.DocuSign.OAuth)[:client_id],
    client_secret: Application.fetch_env!(:ueberauth, Ueberauth.Strategy.DocuSign.OAuth)[:client_secret],
    site: "https://account.docusign.com",
    token_url: "/oauth/token",
    params: %{"refresh_token" => refresh_token}
  )

  case OAuth2.Client.get_token(client) do
    {:ok, %OAuth2.Client{token: new_token}} ->
      {:ok, new_token}
    {:error, error} ->
      {:error, error}
  end
end
```

## Security Considerations

### CSRF Protection

The library includes built-in CSRF protection via the `state` parameter. Always verify the state parameter in production:

```elixir
# Generate a secure state parameter
state = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

# Store in session before redirect
conn
|> put_session(:oauth_state, state)
|> redirect(to: Routes.auth_path(conn, :request, :docusign, state: state))

# Verify in callback
def callback(conn, %{"state" => state} = params) do
  if state == get_session(conn, :oauth_state) do
    # Process callback
  else
    # Reject - possible CSRF attack
  end
end
```

### Secure Storage

- Never commit credentials to version control
- Use environment variables or secret management systems
- Encrypt tokens when storing in database
- Implement token rotation for long-lived sessions

## Error Handling

The library provides detailed error information in the `ueberauth_failure` struct:

```elixir
def callback(%{assigns: %{ueberauth_failure: fails}} = conn, _params) do
  case fails.errors |> List.first() do
    %{message: "access_denied"} ->
      # User denied authorization

    %{message: "invalid_grant"} ->
      # Invalid or expired authorization code

    %{message_key: "missing_code"} ->
      # No authorization code received

    _ ->
      # Other errors
  end
end
```

## Testing

The library includes comprehensive test coverage. Run tests with:

```bash
mix test
```

For integration tests with real DocuSign API:

```bash
# Copy and configure test credentials
cp config/test.secret.exs.template config/test.secret.exs

# Run integration tests
mix test --only integration
```

## Development

### Setting Up Development Environment

```bash
# Clone the repository
git clone https://github.com/neilberkman/ueberauth_docusign.git
cd ueberauth_docusign

# Install dependencies
mix deps.get

# Run tests
mix test

# Run quality checks
mix format --check-formatted
mix credo --strict
mix dialyzer
```

### Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request

## Troubleshooting

### Common Issues

**Invalid Grant Error**

- Ensure your redirect URI exactly matches the one configured in DocuSign
- Check that the authorization code hasn't expired (they're only valid for a few minutes)

**Consent Required**

- For JWT/impersonation flows, ensure admin consent has been granted
- Users may need to explicitly grant permission on first login

**Token Expiration**

- Access tokens expire after 8 hours by default
- Implement token refresh logic for long-running sessions

## Links

- [Hex Package](https://hex.pm/packages/ueberauth_docusign)
- [Documentation](https://hexdocs.pm/ueberauth_docusign)
- [DocuSign Developer Center](https://developers.docusign.com)
- [DocuSign OAuth Guide](https://developers.docusign.com/platform/auth/authcode/)
- [DocuSign Elixir Client](https://hex.pm/packages/docusign)

## License

MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

This library is part of the DocuSign Elixir ecosystem, designed to work seamlessly with the [docusign](https://hex.pm/packages/docusign) API client library.
