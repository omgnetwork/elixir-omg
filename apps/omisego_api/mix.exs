defmodule OmiseGO.API.MixProject do
  use Mix.Project

  def project do
    [
      app: :omisego_api,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix_pubsub, "~> 1.0"},
      {:ex_rlp, "~> 0.2.1"},
      {:blockchain, "~> 0.1.6"},
      {:ex_unit_fixtures, "~> 0.3.1", only: [:test]},
      #
      {:omisego_db, in_umbrella: true},
      {:omisego_eth, in_umbrella: true},
    ]
  end
end
