defmodule OMG.Watcher.MixProject do
  use Mix.Project

  def project() do
    [
      app: :omg_watcher,
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

  # Run "mix help compile.app" to learn about applications.
  def application() do
    [
      mod: {OMG.Watcher.Application, []},
      start_phases: [{:attach_telemetry, []}],
      extra_applications: [:logger, :runtime_tools, :telemetry, :phoenix, :poison]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp deps() do
    [
      {:telemetry, "~> 0.4.1"},
      # there's no apparent reason why libsecp256k1, spandex need to be included as dependencies
      # to this umbrella application apart from mix ecto.gen.migration not working, so here they are, copied from
      # the parent (main) mix.exs
      {:spandex, "~> 3.0.2"},

      # UMBRELLA
      {:omg_bus, in_umbrella: true},
      {:omg, in_umbrella: true},
      {:omg_status, in_umbrella: true},
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true},
      {:omg_utils, in_umbrella: true},

      # TEST ONLY
      # here only to leverage common test helpers and code
      {:fake_server, "~> 2.1", only: [:dev, :test], runtime: false},
      {:briefly, "~> 0.3.0", only: [:dev, :test]}
    ]
  end
end
