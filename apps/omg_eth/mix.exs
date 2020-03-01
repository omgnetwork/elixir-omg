defmodule OMG.Eth.MixProject do
  use Mix.Project

  require Logger

  def project() do
    [
      app: :omg_eth,
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
      mod: {OMG.Eth.Application, []},
      extra_applications: [:sasl, :logger]
    ]
  end

  # Specifies which paths to compile per environment.
  # :dev compiles `test/support` to gain access to various `Support.*` helpers
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp deps() do
    [
      {:ex_abi, "~> 0.2.1"},
      {:ethereumex,
       git: "https://github.com/mana-ethereum/ethereumex.git", ref: "b5b8a6057bb26ce6dc6365bbb8b699d72b13b7b1"},
      # Umbrella
      {:omg_bus, in_umbrella: true},
      {:omg_status, in_umbrella: true},
      {:omg_utils, in_umbrella: true},
      # TEST ONLY
      {:exexec, git: "https://github.com/pthomalla/exexec.git", branch: "add_streams", only: [:dev, :test]},
      {:briefly, "~> 0.3.0", only: [:dev, :test]},
      {:exvcr, "~> 0.10", only: :test}
    ]
  end
end
