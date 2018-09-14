defmodule OMG.JSONRPC.Mixfile do
  use Mix.Project

  def project do
    [
      app: :omg_jsonrpc,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      env: [
        # our own rpc port where OMG.API is exposed
        omg_api_rpc_port: 9656
      ],
      extra_applications: [:logger],
      mod: {OMG.JSONRPC.Application, []}
    ]
  end

  defp deps do
    [
      {:jsonrpc2, "~> 1.1"},
      {:cowboy, "~> 1.1"},
      {:plug, "1.5.0", override: true},
      {:poison, "~> 3.1"}
    ]
  end
end
