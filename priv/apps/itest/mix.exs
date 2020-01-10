defmodule Itest.MixProject do
  use Mix.Project

  def project do
    [
      app: :itest,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      build_path: "../../_build" <> if(System.get_env("DOCKER"), do: "_docker", else: ""),
      config_path: "../../config/config.exs",
      deps_path: "../../deps" <> if(System.get_env("DOCKER"), do: "_docker", else: ""),
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
      {:ex_plasma, git: "https://github.com/omisego/ex_plasma.git"},
      {:watcher_info_api, in_umbrella: true},
      {:watcher_security_critical_api, in_umbrella: true},
      {:child_chain_api, in_umbrella: true},
      {:eip_55, "~> 0.1"},
      {:ethereumex, "~> 0.5.5"},
      {:ex_abi, "~> 0.2.1"},
      {:websockex, "~> 0.4.2"},
      {:ex_abi, "~> 0.2.1"},
      {:ex_rlp, "~> 0.5.2"},
      {:libsecp256k1, git: "https://github.com/omisego/libsecp256k1.git", branch: "elixir-only", override: true},
      {:poison, "~> 3.0"},
      {:tesla, "~> 1.3"},
      {:hackney, "~> 1.15.2"},
      {:cabbage, "~> 0.3.0"}
    ]
  end
end
