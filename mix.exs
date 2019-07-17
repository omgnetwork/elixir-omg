defmodule OMG.Umbrella.MixProject do
  use Mix.Project

  def umbrella_version, do: "0.2.0"

  def project do
    [
      # name the ap for the sake of `mix coveralls --umbrella`
      # see https://github.com/parroty/excoveralls/issues/23#issuecomment-339379061
      app: :omg_umbrella,
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
      # gets all apps test folders for the sake of `mix coveralls --umbrella`
      test_paths: test_paths(),
      aliases: aliases(),
      # Docs
      source_url: "https://github.com/omisego/elixir-omg"
    ]
  end

  defp test_paths do
    "apps/*/test" |> Path.wildcard() |> Enum.sort()
  end

  defp deps do
    [
      {:distillery, "~> 2.0", runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0.5", only: [:dev, :test], runtime: false},
      # https://github.com/xadhoom/excoveralls.git `52c6c8e5d7fe9abb814e5e3e546c863b9b2b41b7` rebased on `master`
      # more or less around v0.11.1
      {:excoveralls,
       git: "https://github.com/omisego/excoveralls.git",
       ref: "23b97648ff5ed7b19d75364233bbf3e5fcb407ad",
       only: [:test],
       runtime: false},
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
      "coveralls.circle": ["coveralls.circle --no-start"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run apps/omg_watcher/priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end

  defp dialyzer do
    [
      flags: [:error_handling, :race_conditions, :underspecs, :unknown, :unmatched_returns],
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
