defmodule OMG.MixProject do
  use Mix.Project

  def project() do
    [
      app: :omg,
      version: "#{String.trim(File.read!("../../VERSION"))}",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application() do
    [
      mod: {OMG.Application, []},
      extra_applications: [:logger, :sentry, :telemetry]
    ]
  end

  # Specifies which paths to compile per environment.
  # :dev compiles `test/support` to gain access to various `Support.*` helpers
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp deps() do
    [
      {:ex_plasma, git: "https://github.com/omisego/ex_plasma.git", ref: "c220f4087957bf98db63fc6250cdc1ca37a89a52"},
      {:ex_rlp, "~> 0.5.3"},
      {:merkle_tree, "~> 2.0.0"},
      {:telemetry, "~> 0.4.1"},
      # UMBRELLA
      {:omg_bus, in_umbrella: true},
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true},
      {:omg_status, in_umbrella: true}
    ]
  end
end
