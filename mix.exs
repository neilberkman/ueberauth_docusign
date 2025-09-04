defmodule UeberauthDocusign.MixProject do
  @moduledoc false
  use Mix.Project

  alias Ueberauth.Strategy.DocuSign
  alias Ueberauth.Strategy.DocuSign.OAuth

  @version "0.1.0"
  @url "https://github.com/neilberkman/ueberauth_docusign"
  @maintainers ["Neil Berkman"]

  def project do
    [
      name: "Ueberauth DocuSign",
      app: :ueberauth_docusign,
      version: @version,
      elixir: "~> 1.16 or ~> 1.17 or ~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: docs(),
      source_url: @url,
      homepage_url: @url,
      description: "DocuSign OAuth2 strategy for Überauth",
      maintainers: @maintainers,
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_add_apps: [:mix]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :oauth2, :ueberauth]
    ]
  end

  defp deps do
    [
      # Runtime dependencies
      {:oauth2, "~> 2.0"},
      {:ueberauth, "~> 0.10"},
      {:jason, "~> 1.4"},

      # Test dependencies
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.0", only: :test},

      # Dev dependencies
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:quokka, "~> 2.11", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      extras: [
        "README.md",
        "CHANGELOG.md": [title: "Changelog"]
      ],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @url,
      formatters: ["html"],
      groups_for_modules: [
        "OAuth Strategy": [
          DocuSign,
          OAuth
        ]
      ]
    ]
  end

  defp package do
    [
      name: "ueberauth_docusign",
      maintainers: @maintainers,
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@url}/blob/main/CHANGELOG.md",
        "GitHub" => @url
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end
end
