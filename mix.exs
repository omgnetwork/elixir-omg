defmodule OmiseGO.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [coveralls: :test, "coveralls.html": :test, "coveralls.detail": :test, dialyzer: :prod],
      dialyzer: [
        flags: [:error_handling, :race_conditions, :underspecs, :unknown, :unmatched_returns],
        plt_add_deps: :transitive,
        ignore_warnings: "dialyzer.ignore-warnings"
      ],
      test_coverage: [tool: ExCoveralls],
      aliases: [
        test: ["test --no-start"],
        coveralls: ["coveralls --no-start"],
        "coveralls.html": ["coveralls.html --no-start"],
        "coveralls.detail": ["coveralls.detail --no-start"]
      ]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.5", only: [:prod], runtime: false},
      {:credo, "~> 0.9", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.8", only: [:test], runtime: false},
      {:licensir, "~> 0.2.0", only: :dev, runtime: false},
      # NOTE: we're overriding for the sake of `omisego_api` mix.exs deps. Otherwise the override is ignored
      # TODO: making it consistent is advised: maybe discuss with exth_crypto and submit pr there?
      {:libsecp256k1, "~> 0.1.4", compile: "${HOME}/.mix/rebar compile", override: true}
    ]
  end
end
