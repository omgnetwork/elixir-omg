defmodule OMG.ChildChain.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_child_chain,
      version: "0.2.0",
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
      extra_applications: [:logger, :telemetry],
      start_phases: [{:boot_done, []}, {:attach_telemetry, []}],
      mod: {OMG.ChildChain.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:ex_rlp, "~> 0.5.2"},
      {:deferred_config, "~> 0.1.1"},
      {:telemetry, "~> 0.4.0"},
      #
      {:omg, in_umbrella: true},
      {:omg_status, in_umbrella: true},
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true},
      {:omg_utils, in_umbrella: true},
      {:omg_child_chain_rpc, in_umbrella: true, only: [:test]}
    ]
  end
end
