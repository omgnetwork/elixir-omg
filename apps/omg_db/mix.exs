defmodule OMG.DB.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_db,
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
      extra_applications: [:logger],
      mod: {OMG.DB.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:appsignal, "~> 1.0"},
      # version caused by dependency in merkle_patricia_tree from blockchain
      {:exleveldb, "~> 0.11"},
      # NOTE: we only need in :dev and :test here, but we need in :prod too in performance
      #       then there's some unexpected behavior of mix that won't allow to mix these, see
      #       [here](https://elixirforum.com/t/mix-dependency-is-not-locked-error-when-building-with-edeliver/7069/3)
      #       OMG-373 (Elixir 1.8) should fix this
      # TEST ONLY
      {:briefly, "~> 0.3.0", only: [:dev, :test], runtime: false}
    ]
  end
end
