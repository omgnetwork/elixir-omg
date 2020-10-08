defmodule Perf.MixProject do
  use Mix.Project

  def project do
    [
      app: :perf,
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end
end
