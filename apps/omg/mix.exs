defmodule OMG.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg,
      version: OMG.Umbrella.MixProject.umbrella_version(),
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
        # we're using a shared (in `omg` app) config entry. The reason here is to minimize risk of Child Chain server's
        # and Watcher's configuration entries diverging (it would be bad, as they must share the same value of this).
        # However, this sharing isn't elegant, as this setting is never read in `:omg` app per se
        deposit_finality_margin: 10,
        ethereum_events_check_interval_ms: 500,
        coordinator_eth_height_check_interval_ms: 6_000
      ],
      extra_applications: [:logger, :appsignal]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:poison, "~> 3.1"},
      {:propcheck, "~> 1.1", only: [:dev, :test]},
      {:ex_rlp, "~> 0.2.1"},
      {:blockchain, "~> 0.1.6"},
      {:merkle_tree, "~> 1.5.0"},
      {:deferred_config, "~> 0.1.1"},
      {:appsignal, "~> 1.0"},
      #
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true}
    ]
  end
end
