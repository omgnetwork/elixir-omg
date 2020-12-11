defmodule OMG.Eth.MixProject do
  use Mix.Project

  require Logger

  def project() do
    [
      app: :omg_eth,
      version: version(),
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
      mod: {OMG.Eth.Application, []},
      start_phases: [{:attach_telemetry, []}],
      extra_applications: [:sasl, :logger, :ex_plasma, :ex_rlp]
    ]
  end

  defp version() do
    "git"
    |> System.cmd(["describe", "--tags", "--abbrev=0"])
    |> elem(0)
    |> String.replace("v", "")
    |> String.replace("\n", "")
  end

  # Specifies which paths to compile per environment.
  # :dev compiles `test/support` to gain access to various `Support.*` helpers
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp deps() do
    [
      {:ex_abi, "~> 0.4"},
      {:ethereumex, "~> 0.6.0"},
      {:ex_secp256k1, "~> 0.1.2"},
      # Umbrella
      {:omg_bus, in_umbrella: true},
      {:omg_status, in_umbrella: true},
      {:omg_utils, in_umbrella: true},
      {:omg_db, in_umbrella: true},
      # TEST ONLY
      {:exexec, "~> 0.2.0", only: [:dev, :test]},
      {:briefly, "~> 0.3.0", only: [:dev, :test]}
    ]
  end
end
