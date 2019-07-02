defmodule OMG.Umbrella.MixProject do
  use Mix.Project

  def umbrella_version, do: "0.2.0"

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.circle": :test,
        dialyzer: :test
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
      {:distillery, "~> 2.0", runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0.5", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.11.1", only: [:test], runtime: false},
      {:licensir, "~> 0.2.0", only: :dev, runtime: false},
      {
        :ex_unit_fixtures,
        git: "https://github.com/omisego/ex_unit_fixtures.git", branch: "feature/require_files_not_load", only: [:test]
      },
      {:ex_doc, "~> 0.20.2", only: :dev, runtime: false},
      {:statix, "~> 1.1"},
      {:appsignal, "~> 1.9"},
      {:sentry, "~> 7.0"},
      {:spandex, "~> 2.4"},
      {:spandex_datadog, "~> 0.4"},
      {:decorator, "~> 1.2"},
      {:libsecp256k1,
       git: "https://github.com/InoMurko/libsecp256k1.git",
       ref: "83d4c91b7b5ad79fdd3c020be8c57ff6e2212780",
       override: true}
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
      flags: [:specdiffs, :error_handling, :race_conditions, :underspecs, :unknown, :unmatched_returns],
      ignore_warnings: "dialyzer.ignore-warnings",
      list_unused_filters: true,
      plt_add_apps: plt_apps()
    ]
  end

  defp plt_apps,
    do: [
      :briefly,
      :cowboy,
      :distillery,
      :ex_unit,
      :exexec,
      :fake_server,
      :iex,
      :jason,
      :mix,
      :plug,
      :propcheck,
      :proper,
      :ranch,
      :sentry,
      :vmstats,
      :statix
    ]
end
