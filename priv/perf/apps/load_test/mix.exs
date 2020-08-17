defmodule LoadTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :load_test,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
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

  # Specifies which paths to compile per environment.
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:briefly, "~> 0.3"},
      {:chaperon, "~> 0.3.1"},
      {:tesla, "~> 1.3.0"},
      {:httpoison, "~> 1.6.2", override: true},
      {:ex_plasma, git: "https://github.com/omisego/ex_plasma.git", override: true},

      # Better adapter for tesla
      {:hackney, "~> 1.15.2"},
      {:watcher_info_api, in_umbrella: true},
      {:watcher_security_critical_api, in_umbrella: true},
      {:child_chain_api, in_umbrella: true}
    ]
  end
end
