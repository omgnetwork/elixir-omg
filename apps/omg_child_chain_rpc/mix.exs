defmodule OMG.ChildChainRPC.MixProject do
  use Mix.Project

  def project() do
    [
      app: :omg_child_chain_rpc,
      version: "#{String.trim(File.read!("../../VERSION"))}",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application() do
    [
      mod: {OMG.ChildChainRPC.Application, []},
      extra_applications: [:logger, :runtime_tools, :sasl, :telemetry]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps() do
    [
      {:phoenix, "~> 1.5"},
      {:poison, "~> 4.0"},
      {:plug_cowboy, "~> 2.3"},
      {:httpoison, "~> 1.6", override: true},
      {:cors_plug, "~> 2.0"},
      {:spandex_phoenix, "~> 0.4.1"},
      {:spandex_datadog, "~> 0.4"},
      {:telemetry, "~> 0.4.1"},
      #
      {:omg_bus, in_umbrella: true},
      {:omg_status, in_umbrella: true},
      {:omg_utils, in_umbrella: true},
      {:omg_child_chain, in_umbrella: true}
    ]
  end
end
