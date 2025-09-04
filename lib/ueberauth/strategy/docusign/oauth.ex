defmodule Ueberauth.Strategy.DocuSign.OAuth do
  @moduledoc """
  OAuth2 client for DocuSign.

  Configures the OAuth2 strategy for DocuSign authentication.
  """

  use OAuth2.Strategy

  alias OAuth2.Strategy.AuthCode
  alias Ueberauth.Strategy.DocuSign.OAuth

  @defaults [
    strategy: __MODULE__,
    site: "https://account.docusign.com",
    authorize_url: "/oauth/auth",
    token_url: "/oauth/token"
  ]

  @doc """
  Construct a client for requests to DocuSign.

  This will be setup automatically for you in `Ueberauth.Strategy.DocuSign`.

  These options are only useful for usage outside the normal callback phase of Ueberauth.
  """
  def client(opts \\ []) do
    config =
      :ueberauth
      |> Application.fetch_env!(OAuth)
      |> check_config_key_exists(:client_id)
      |> check_config_key_exists(:client_secret)

    client_opts =
      @defaults
      |> Keyword.merge(config)
      |> Keyword.merge(opts)

    json_library = Ueberauth.json_library()

    OAuth2.Client.new(client_opts)
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth.
  No need to call this usually.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client()
    |> OAuth2.Client.authorize_url!(params)
  end

  def get(token, url, headers \\ [], opts \\ []) do
    [token: token]
    |> client()
    |> put_param("client_secret", client().client_secret)
    |> OAuth2.Client.get(url, headers, opts)
  end

  def get_access_token(params \\ [], opts \\ []) do
    case opts |> client() |> OAuth2.Client.get_token(params) do
      {:error, %OAuth2.Response{body: _body, status_code: 401}} ->
        {:error, %OAuth2.Error{reason: "unauthorized"}}

      {:error, %OAuth2.Response{body: body, status_code: 400}} ->
        {:error, %OAuth2.Error{reason: body["error"] || "bad_request"}}

      {:error, %OAuth2.Error{reason: reason}} ->
        {:error, %OAuth2.Error{reason: reason}}

      {:ok, %OAuth2.Client{token: %OAuth2.AccessToken{} = token}}
      when is_nil(token.access_token) or token.access_token == "" ->
        {:error, %OAuth2.Error{reason: token.other_params["error_description"] || "invalid_token"}}

      {:ok, %OAuth2.Client{token: token}} ->
        {:ok, token}
    end
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_param("client_secret", client.client_secret)
    |> put_header("Accept", "application/json")
    |> AuthCode.get_token(params, headers)
  end

  defp check_config_key_exists(config, key) when is_list(config) do
    if !Keyword.has_key?(config, key) do
      raise "#{inspect(key)} missing from config :ueberauth, Ueberauth.Strategy.DocuSign.OAuth"
    end

    config
  end

  defp check_config_key_exists(_, _) do
    raise "Config :ueberauth, Ueberauth.Strategy.DocuSign.OAuth is not a keyword list, as expected"
  end
end
