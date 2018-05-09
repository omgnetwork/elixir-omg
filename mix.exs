defmodule OmiseGO.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [coveralls: :test, "coveralls.html": :test, "coveralls.detail": :test],
      dialyzer: [flags: [:error_handling, :race_conditions, :underspecs, :unknown, :unmatched_returns],
                 plt_add_deps: :transitive,
                 ignore_warnings: "dialyzer.ignore-warnings"
                ],
      test_coverage: [tool: ExCoveralls],
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:credo, "~> 0.9", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.8", only: [:test], runtime: false},
      # NOTE: we're overriding for the sake of `omisego_api` mix.exs deps. Otherwise the override is ignored
      # TODO: making it consistent is advised: maybe discuss with exth_crypto and submit pr there?
      {:libsecp256k1, "~> 0.1.4", compile: "${HOME}/.mix/rebar compile", override: true}
    ]
  end
end
