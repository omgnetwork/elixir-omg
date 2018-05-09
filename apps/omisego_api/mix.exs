defmodule OmiseGO.API.MixProject do
  use Mix.Project

  def project do
    [
      app: :omisego_api,
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

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      env: [
        ethereum_event_block_finality_margin: 10,
        ethereum_event_get_deposits_interval_ms: 5_000,
        ethereum_event_check_height_interval_ms: 1_000,
        ethereum_event_max_block_range_in_deposits_query: 5,
        child_block_submit_period: 1
      ],
      extra_applications: [:logger],
      mod: {OmiseGO.API.Application, []},
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix_pubsub, "~> 1.0"},
      {:ex_rlp, "~> 0.2.1"},
      {:blockchain, "~> 0.1.6"},
      {:ex_unit_fixtures, "~> 0.3.1", only: [:test]},
      {:jsonrpc2, "~> 1.0", only: [:test]},
      {:merkle_tree, git: "https://github.com/omisego/merkle_tree.git"},
      {:libsecp256k1, "~> 0.1.2", compile: "${HOME}/.mix/rebar compile", override: true},
      #
      {:omisego_db, in_umbrella: true},
      {:omisego_eth, in_umbrella: true},
    ]
  end
end
