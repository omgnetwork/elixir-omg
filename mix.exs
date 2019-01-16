defmodule OMG.Umbrella.MixProject do
  use Mix.Project

  def umbrella_version, do: "0.1.0"

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        dialyzer: :prod
      ],
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      aliases: aliases(),
      # Docs
      source_url: "https://github.com/omisego/elixir-omg"
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.5", only: [:prod], runtime: false},
      {:credo, "~> 0.10.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10.3", only: [:test], runtime: false},
      {:licensir, "~> 0.2.0", only: :dev, runtime: false},
      {
        :ex_unit_fixtures,
        git: "https://github.com/omisego/ex_unit_fixtures.git", branch: "feature/require_files_not_load", only: [:test]
      },
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:appsignal, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      test: ["test --no-start"],
      coveralls: ["coveralls --no-start"],
      "coveralls.html": ["coveralls.html --no-start"],
      "coveralls.detail": ["coveralls.detail --no-start"],
      "coveralls.post": ["coveralls.post --no-start"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run apps/omg_watcher/priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end

  defp dialyzer do
    [
      paths: [
        "_build/prod/lib/omg_watcher/ebin",
        "_build/prod/lib/omg_rpc/ebin",
        "_build/prod/lib/omg_api/ebin",
        "_build/prod/lib/omg_eth/ebin",
        "_build/prod/lib/omg_db/ebin"
      ],
      flags: [:error_handling, :race_conditions, :underspecs, :unknown, :unmatched_returns],
      plt_add_deps: :transitive,
      plt_add_apps: [:mix],
      ignore_warnings: "dialyzer.ignore-warnings"
    ]
  end
end
