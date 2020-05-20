defmodule OMG.WatcherInfo.MixProject do
  use Mix.Project

  def project() do
    [
      app: :omg_watcher_info,
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

  def application() do
    [
      mod: {OMG.WatcherInfo.Application, []},
      extra_applications: [:logger, :runtime_tools, :telemetry]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp deps() do
    [
      {:postgrex, "~> 0.14"},
      {:ecto_sql, "~> 3.1"},
      {:telemetry, "~> 0.4.1"},
      {:spandex_ecto, "~> 0.6.0"},
      # there's no apparent reason why libsecp256k1, spandex need to be included as dependencies
      # to this umbrella application apart from mix ecto.gen.migration not working, so here they are, copied from
      # the parent (main) mix.exs
      {:libsecp256k1, git: "https://github.com/omisego/libsecp256k1.git", branch: "elixir-only", override: true},
      {:spandex, "~> 2.4.3"},
      {:jason, "~> 1.0"},

      # UMBRELLA
      {:omg, in_umbrella: true},
      {:omg_status, in_umbrella: true},
      {:omg_utils, in_umbrella: true},

      # TEST ONLY
      # here only to leverage common test helpers and code
      {:fake_server, "~> 1.5", only: [:dev, :test], runtime: false},
      {:briefly, "~> 0.3.0", only: [:dev, :test]},
      {:omg_child_chain, in_umbrella: true, only: [:test], runtime: false},
      {:phoenix, "~> 1.5", runtime: false},
      {:ex_machina, "~> 2.3", only: [:test], runtime: false}
    ]
  end
end
