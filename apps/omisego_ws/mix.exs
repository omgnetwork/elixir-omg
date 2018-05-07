defmodule OmiseGO.WS.Mixfile do
  use Mix.Project

  def project do
    [
      app: :omisego_ws,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      env: [
        # our own ws port where OmiseGO.API is exposed
        omisego_api_ws_port: 4004
      ],
      extra_applications: [:logger],
      mod: {OmiseGO.WS.Application, []}
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 1.1"},
      {:poison, "~> 3.1"},
      {:ex_unit_fixtures, "~> 0.3.1", only: [:test]},
      {:socket, "~> 0.3"},
      {:omisego_api, in_umbrella: true, runtime: false}
    ]
  end
end
