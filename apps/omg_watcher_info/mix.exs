defmodule OMG.WatcherInfo.MixProject do
  use Mix.Project

  def project() do
    [
      app: :omg_watcher_info,
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
      mod: {OMG.WatcherInfo.Application, []},
      start_phases: [{:attach_telemetry, []}],
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
      {:postgrex, "~> 0.15"},
      {:ecto_sql, "~> 3.4"},
      {:telemetry, "~> 0.4.1"},
      {:spandex_ecto, "~> 0.6.0"},
      # there's no apparent reason why libsecp256k1, spandex need to be included as dependencies
      # to this umbrella application apart from mix ecto.gen.migration not working, so here they are, copied from
      # the parent (main) mix.exs

      {:spandex, "~> 3.0.2"},
      {:jason, "~> 1.0"},

      # UMBRELLA
      {:omg_status, in_umbrella: true},
      {:omg_utils, in_umbrella: true},

      # TEST ONLY
      # here only to leverage common test helpers and code
      {:fake_server, "~> 2.1", only: [:dev, :test], runtime: false},
      {:briefly, "~> 0.3.0", only: [:dev, :test]},
      {:phoenix, "~> 1.5", runtime: false},
      {:poison, "~> 4.0"},
      {:ex_machina, "~> 2.3", only: [:test], runtime: false}
    ]
  end
end
