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
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:omisego_api, in_umbrella: true}
    ]
  end
end
