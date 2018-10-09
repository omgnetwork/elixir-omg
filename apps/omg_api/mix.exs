defmodule OMG.API.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_api,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      env: [
        ethereum_event_block_finality_margin: 10,
        ethereum_event_get_deposits_interval_ms: 5_000,
        ethereum_event_check_height_interval_ms: 5_000,
        child_block_submit_period: 1,
        rootchain_height_sync_interval_ms: 5_000
      ],
      extra_applications: [:logger],
      mod: {OMG.API.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:poison, "~> 3.1"},
      {:propcheck, "~> 1.1", only: [:dev, :test]},
      {:phoenix_pubsub, "~> 1.0"},
      {:ex_rlp, "~> 0.2.1"},
      {:blockchain, "~> 0.1.6"},
      {:merkle_tree,
       git: "https://github.com/omisego/merkle_tree.git", branch: "feature/omg-184-add-option-to-not-hash-leaves"},
      {:libsecp256k1, "~> 0.1.4", compile: "${HOME}/.mix/rebar compile", override: true},
      #
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true},
      {:omg_jsonrpc, in_umbrella: true}
    ]
  end
end
