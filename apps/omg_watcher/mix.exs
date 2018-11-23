defmodule OMG.Watcher.Mixfile do
  use Mix.Project

  def project do
    [
      app: :omg_watcher,
      version: "0.0.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :phoenix_swagger] ++ Mix.compilers(),
      start_permanent: Mix.env() in [:dev, :prod],
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      env: [
        eth_exit_finality_margin: 12
      ],
      mod: {OMG.Watcher.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:phoenix, "~> 1.3.2"},
      {:phoenix_ecto, "~> 3.3"},
      {:phoenix_swagger, "~> 0.8.1"},
      {:postgrex, ">= 0.13.5"},
      {:deferred_config, "~> 0.1.1"},
      {:cowboy, "~> 1.1"},
      # NOTE: fixed version needed b/c Plug.Conn.WrapperError.reraise/3 is deprecated... 2 occurences in umbrella.
      {:plug, "1.7.0", override: true},
      {:socket, "~> 0.3"},
      {:libsecp256k1, "~> 0.1.4", compile: "${HOME}/.mix/rebar compile", override: true},
      # TODO: we only need in :dev and :test here, but we need in :prod too in performance
      #       then there's some unexpected behavior of mix that won't allow to mix these, see
      #       [here](https://elixirforum.com/t/mix-dependency-is-not-locked-error-when-building-with-edeliver/7069/3)
      {:briefly, "~> 0.3"},
      {:httpoison, "~> 1.1.0"},
      #
      {:omg_api, in_umbrella: true, runtime: false},
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true}
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
