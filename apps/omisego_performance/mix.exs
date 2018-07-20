defmodule OmiseGO.Performance.MixProject do
  use Mix.Project

  def project do
    [
      app: :omisego_performance,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :tools]
    ]
  end

  defp deps do
    [
      {:jsonrpc2, "~> 1.1"},
      {:briefly, "~> 0.3", only: [:dev, :test]},
      {:hackney, "~> 1.7"},
      {:omisego_api, in_umbrella: true, runtime: false},
      {:omisego_jsonrpc, in_umbrella: true, runtime: false}
    ]
  end
end
