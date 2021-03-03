defmodule OMG.WatcherRPC.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :omg_watcher_rpc,
      version: version(),
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

  def application() do
    [
      mod: {OMG.WatcherRPC.Application, []},
      extra_applications: [:logger, :runtime_tools, :telemetry, :omg_watcher]
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
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp deps() do
    [
      {:phoenix, "~> 1.5"},
      {:poison, "~> 4.0"},
      {:plug_cowboy, "~> 2.3"},
      {:cors_plug, "~> 2.0"},
      {:spandex_phoenix, "~> 1.0"},
      {:spandex_datadog, "~> 1.0"},
      {:telemetry, "~> 0.4.1"},
      # UMBRELLA
      {:omg_bus, in_umbrella: true},
      {:omg_utils, in_umbrella: true},
      {:omg_watcher, in_umbrella: true},
      # UMBRELLA but test only
      {:omg_watcher_info, in_umbrella: true, only: [:test]},
      # TEST ONLY
      {:ex_machina, "~> 2.3", only: [:test], runtime: false}
    ]
  end
end
