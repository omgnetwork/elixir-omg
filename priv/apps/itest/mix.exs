defmodule Itest.MixProject do
  use Mix.Project

  def project do
    [
      app: :itest,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:eip_55, "~> 0.1"},
      {:watchers_informational_api, in_umbrella: true},
      {:watcher_security_critical_api, in_umbrella: true},
      {:child_chain_api, in_umbrella: true},
      {:ethereumex, "~> 0.5.5"},
      {:ex_abi, "~> 0.2.1"},
      {:ex_rlp, "~> 0.5.2"},
      {:libsecp256k1, git: "https://github.com/omisego/libsecp256k1.git", branch: "elixir-only", override: true},
      {:poison, "~> 3.0"},
      {:tesla, "~> 1.2"},
      {:white_bread, "~> 4.5.0", only: [:dev, :test]},
      {:child_chain_api, in_umbrella: true},
      {:watcher_security_critical_api, in_umbrella: true},
      {:watchers_informational_api, in_umbrella: true}
    ]
  end
end
