#!/usr/bin/env elixir
# Test OAuth with real DocuSign credentials

Mix.install([
  {:ueberauth_docusign, path: "."},
  {:ueberauth, "~> 0.10"},
  {:httpoison, "~> 2.0"}
])

# Real credentials from 1Password
Application.put_env(:ueberauth, Ueberauth.Strategy.DocuSign.OAuth,
  client_id: "4a3a7a9d-56cb-48f9-a9e5-e3da04b5484c",
  client_secret: "0c54cf63-8a1a-460f-8a6c-cf7141fc4728"
)

alias Ueberauth.Strategy.DocuSign.OAuth

IO.puts("\n========================================")
IO.puts("   DocuSign OAuth Real Credentials Test")
IO.puts("========================================\n")

# Test 1: Generate Authorization URL
IO.puts("1. Testing OAuth URL Generation:")
IO.puts("---------------------------------")

auth_url =
  OAuth.authorize_url!(
    [
      scope: "signature extended",
      state: "test_state_#{:rand.uniform(10000)}",
      redirect_uri: "http://localhost:4000/auth/docusign/callback"
    ],
    site: "https://account-d.docusign.com"
  )

IO.puts("Generated Authorization URL:")
IO.puts(auth_url)
IO.puts("")

# Verify URL structure
if auth_url =~ "client_id=4a3a7a9d-56cb-48f9-a9e5-e3da04b5484c" do
  IO.puts("✅ Real client ID included in URL")
else
  IO.puts("❌ Client ID not found in URL")
end

# Test 2: Client Configuration
IO.puts("\n2. Testing OAuth Client Configuration:")
IO.puts("---------------------------------------")

client = OAuth.client(site: "https://account-d.docusign.com")
IO.puts("Client ID: #{client.client_id}")
IO.puts("Site: #{client.site}")
IO.puts("Authorize URL: #{client.authorize_url}")
IO.puts("Token URL: #{client.token_url}")

# Test 3: Test Invalid Code Exchange (should fail gracefully)
IO.puts("\n3. Testing Invalid Code Exchange:")
IO.puts("----------------------------------")

try do
  result =
    OAuth.get_token(
      client,
      [
        code: "invalid_test_code",
        redirect_uri: "http://localhost:4000/auth/docusign/callback"
      ],
      []
    )

  case result do
    {:ok, _token} ->
      IO.puts("❌ Unexpected success with invalid code")

    {:error, response} when is_map(response) ->
      IO.puts("✅ Expected error response")
      IO.puts("Error details: #{inspect(response)}")

    {:error, error} ->
      IO.puts("✅ Expected error: #{inspect(error)}")

    other ->
      IO.puts("Response: #{inspect(other)}")
  end
rescue
  e ->
    IO.puts("Error occurred: #{inspect(e)}")
end

# Test 4: Generate Manual Test URL
IO.puts("\n4. Manual Testing Instructions:")
IO.puts("--------------------------------")
IO.puts("To complete a full OAuth flow manually:")
IO.puts("")
IO.puts("1. Open this URL in your browser:")
IO.puts("   #{auth_url}")
IO.puts("")
IO.puts("2. Log in with your DocuSign demo account")
IO.puts("")
IO.puts("3. After authorization, you'll be redirected to:")
IO.puts("   http://localhost:4000/auth/docusign/callback?code=XXXXX&state=XXXXX")
IO.puts("")
IO.puts("4. Copy the 'code' parameter from the URL")
IO.puts("")
IO.puts("5. Run this command with the code:")
IO.puts("   mix run -e 'code = \"YOUR_CODE_HERE\"; ...'")
IO.puts("")

IO.puts("\n========================================")
IO.puts("            Test Complete!")
IO.puts("========================================\n")
