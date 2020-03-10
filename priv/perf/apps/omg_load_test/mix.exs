defmodule LoadTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_load_test,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {LoadTest.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:chaperon, "~> 0.3.1"},
      {:jason, "~> 1.1"},

      # Better adapter for tesla
      {:hackney, "~> 1.15.2"},
      {:ex_plasma, env: :prod, git: "https://github.com/omisego/ex_plasma.git", override: true},
      {:watcher_info_api, in_umbrella: true},
      {:watcher_security_critical_api, in_umbrella: true},
      {:child_chain_api, in_umbrella: true},

      # Test dependencies
      {:ex_unit_fixtures, "~> 0.3.1"},

      # Overrides
      {:cowboy, "~> 2.6", override: true},
      {:httpoison, "~> 1.6.2", override: true}
    ]
  end
end
