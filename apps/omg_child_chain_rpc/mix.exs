defmodule OMG.ChildChainRPC.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_child_chain_rpc,
      version: OMG.Umbrella.MixProject.umbrella_version(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
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
  def application do
    [
      mod: {OMG.ChildChainRPC.Application, []},
      extra_applications: [:logger, :runtime_tools, :sasl]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3"},
      {:plug_cowboy, "~> 1.0"},
      {:deferred_config, "~> 0.1.1"},
      {:httpoison, "~> 1.4.0"},
      {:appsignal, "~> 1.0"},
      {:spandex, "~> 2.4"},
      {:spandex_datadog, "~> 0.4"},
      {:decorator, "~> 1.2"},
      {:cors_plug, "~> 2.0"},
      #
      {:omg_status, in_umbrella: true},
      {:omg_utils, in_umbrella: true}
    ]
  end
end
