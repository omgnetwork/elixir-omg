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
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.8", only: [:test], runtime: false},
    ]
  end
end
