defmodule OMG.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg,
      version: "#{String.trim(File.read!("../../VERSION"))}",
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
      extra_applications: [:logger, :sentry, :telemetry]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:ex_rlp, "~> 0.5.2"},
      {:merkle_tree, "~> 1.6"},
      {:telemetry, "~> 0.4.0"},
      # UMBRELLA
      {:omg_bus, in_umbrella: true},
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true},
      {:omg_status, in_umbrella: true},

      # TEST ONLY

      # Used for mocking websocket servers
      {:plug_cowboy, "~> 1.0", only: [:dev, :test]}
    ]
  end
end
