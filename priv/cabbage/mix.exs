defmodule Specs.MixProject do
  use Mix.Project

  def project() do
    [
      app: :specs,
      apps_path: "apps",
      version: "0.1.0",
      elixir: "~> 1.8.2",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.circle": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application() do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps() do
    [
      {:credo, "~> 1.2.3", only: [:dev, :test], runtime: false}
    ]
  end
end
