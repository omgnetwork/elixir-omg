defmodule OmiseGO.JSONRPC.Mixfile do
  use Mix.Project

  def project do
    [
      app: :omisego_jsonrpc,
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
        # our own rpc port where OmiseGO.API is exposed
        omisego_api_rpc_port: 9656
      ],
      extra_applications: [:logger],
      mod: {OmiseGO.JSONRPC.Application, []}
    ]
  end

  defp deps do
    [
      # required to avoid silencing legitimate FunctionClauseErrors that are raised in handler
      # TODO: make the PR merged and revert to a released version
      #       after that check with forcing a FunctionClauseError be raised when handling a JSONRPC call
      {:jsonrpc2,
       git: "https://github.com/omisego/jsonrpc2-elixir.git", branch: "precise_handling_of_FunctionClauseError"},
      {:cowboy, "~> 1.1"},
      {:plug, "1.5.0", override: true},
      {:poison, "~> 3.1"},
      # test can't run omisego_apis
      {:omisego_api, in_umbrella: true, only: [:dev, :prod]}
    ]
  end
end
