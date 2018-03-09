defmodule HonteD.Integration.Mixfile do
  use Mix.Project

  def project do
    [
      app: :honted_integration,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      start_permanent: false,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
    ]
  end

  def application do
    [
      extra_applications: [],  # we're running using --no-start. Look into test_helper.exs for started apps
    ]
  end

  defp deps do
    [
      {:porcelain, "~> 2.0"},
      {:temp, "~> 0.4"},
      {:socket, "~> 0.3"},
      {:hackney, "~> 1.7"},
      {:ex_unit_fixtures, "~> 0.3.1", only: [:test]},
      {:eep, ~r/.*/, github: "virtan/eep", compile: "rebar compile"}, # regex - match any version
      #
      {:honted_lib, in_umbrella: true},
      {:honted_api, in_umbrella: true},
      {:honted_abci, in_umbrella: true},
      {:honted_ws, in_umbrella: true},
      {:honted_jsonrpc, in_umbrella: true},
    ]
  end
end
