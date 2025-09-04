import Config

alias Ueberauth.Strategy.DocuSign
alias Ueberauth.Strategy.DocuSign.OAuth

if Mix.env() == :test do
  config :ueberauth, OAuth,
    client_id: "test_client_id",
    client_secret: "test_client_secret"

  config :ueberauth, Ueberauth,
    providers: [
      docusign: {DocuSign, [environment: "demo"]}
    ]

  # Load real credentials if available
  if File.exists?("config/test.secret.exs") do
    import_config "test.secret.exs"
  end
end
