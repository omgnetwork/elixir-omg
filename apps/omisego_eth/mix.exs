defmodule OmiseGO.Eth.MixProject do
  use Mix.Project

  def project do
    [
      app: :omisego_eth,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      applications: [:ethereumex]
    ]
  end

  defp deps do
    [
      {:ethereumex, "~> 0.3.1"}
    ]
  end
end
