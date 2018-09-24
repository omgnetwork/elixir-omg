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
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {OMG.Watcher.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.2"},
      {:phoenix_ecto, "~> 3.3"},
      {:phoenix_swagger, "~> 0.8.1"},
      {:postgrex, ">= 0.13.5", only: [:prod, :dev]},
      {:sqlite_ecto2, "~> 2.2", only: [:test]},
      {:cowboy, "~> 1.1"},
      # NOTE: fixed version needed b/c Plug.Conn.WrapperError.reraise/3 is deprecated... 2 occurences in umbrella.
      {:plug, "1.5.0", override: true},
      {:socket, "~> 0.3"},
      {:libsecp256k1, "~> 0.1.4", compile: "${HOME}/.mix/rebar compile", override: true},
      # NOTE: need this explictly, since :omg_jsonrpc won't start jsonrpc2 automatically
      {:jsonrpc2, "~> 1.1"},
      # TODO: we only need in :dev and :test here, but we need in :prod too in performance
      #       then there's some unexpected behavior of mix that won't allow to mix these, see
      #       [here](https://elixirforum.com/t/mix-dependency-is-not-locked-error-when-building-with-edeliver/7069/3)
      {:briefly, "~> 0.3"},
      #
      {:omg_api, in_umbrella: true, runtime: false},
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
