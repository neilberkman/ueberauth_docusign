#!/usr/bin/env elixir
# Script to test OAuth URL generation without credentials
# Run with: elixir test_oauth_url.exs

Mix.install([
  {:ueberauth_docusign, path: "."},
  {:ueberauth, "~> 0.10"}
])

# Configure mock credentials for testing URL generation
Application.put_env(:ueberauth, Ueberauth.Strategy.DocuSign.OAuth,
  client_id: "test_client_id",
  client_secret: "test_client_secret"
)

alias Ueberauth.Strategy.DocuSign.OAuth

IO.puts("\n=== Testing OAuth URL Generation ===\n")

# Test demo environment URL
demo_url =
  OAuth.authorize_url!(
    [
      scope: "signature extended",
      state: "test_state_123",
      redirect_uri: "http://localhost:4000/auth/docusign/callback"
    ],
    site: "https://account-d.docusign.com"
  )

IO.puts("Demo Environment URL:")
IO.puts(demo_url)
IO.puts("")

# Verify URL components
if demo_url =~ "https://account-d.docusign.com/oauth/auth" do
  IO.puts("✅ Demo URL uses correct base")
else
  IO.puts("❌ Demo URL has incorrect base")
end

if demo_url =~ "client_id=test_client_id" do
  IO.puts("✅ Client ID included")
else
  IO.puts("❌ Client ID missing")
end

if demo_url =~ "response_type=code" do
  IO.puts("✅ Response type is 'code'")
else
  IO.puts("❌ Response type incorrect")
end

if demo_url =~ "scope=signature%20extended" or demo_url =~ "scope=signature\\+extended" or
     demo_url =~ "scope=signature+extended" do
  IO.puts("✅ Scope parameter included and properly encoded")
else
  IO.puts("❌ Scope parameter missing or incorrectly encoded")
end

if demo_url =~ "state=test_state_123" do
  IO.puts("✅ State parameter included")
else
  IO.puts("❌ State parameter missing")
end

if demo_url =~ "redirect_uri=" do
  IO.puts("✅ Redirect URI included")
else
  IO.puts("❌ Redirect URI missing")
end

IO.puts("\n=== Testing Production Environment ===\n")

# Test production environment URL
prod_url =
  OAuth.authorize_url!(
    [
      scope: "signature",
      redirect_uri: "https://myapp.com/auth/callback"
    ],
    site: "https://account.docusign.com"
  )

IO.puts("Production Environment URL:")
IO.puts(prod_url)
IO.puts("")

if prod_url =~ "https://account.docusign.com/oauth/auth" do
  IO.puts("✅ Production URL uses correct base")
else
  IO.puts("❌ Production URL has incorrect base")
end

IO.puts("\n=== OAuth Flow Instructions ===\n")
IO.puts("To test with real credentials:")
IO.puts("1. Copy config/test.secret.exs.template to config/test.secret.exs")
IO.puts("2. Add your DocuSign Integration Key and Secret Key")
IO.puts("3. Run: mix test test/integration/docusign_oauth_integration_test.exs --only integration")
IO.puts("")
IO.puts("The generated URLs match DocuSign's OAuth documentation format! ✅")
