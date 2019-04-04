defmodule OMG.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg,
      version: OMG.Umbrella.MixProject.umbrella_version(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      mod: {OMG.Application, []},
      extra_applications: [:logger, :appsignal]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:propcheck, "~> 1.1", only: [:dev, :test]},
      {:ex_rlp, "~> 0.5.2"},
      {:merkle_tree, "~> 1.5.0"},
      {:deferred_config, "~> 0.1.1"},
      {:appsignal, "~> 1.0"},
      {:phoenix_pubsub, "~> 1.0"},
      #
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true},
      {:omg_status, in_umbrella: true}
    ]
  end
end
