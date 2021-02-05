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
      extra_applications: [:logger, :ex_secp256k1],
      mod: {LoadTest.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_rlp, "~> 0.5.3"},
      {:ex_keccak, "~> 0.1.2"},
      {:ex_abi, "~> 0.5.1"},
      {:briefly, "~> 0.3"},
      {:chaperon, "~> 0.3.1"},
      {:statix, "~> 1.4"},
      {:histogrex, "~> 0.0.5"},
      {:tesla, "~> 1.3.0"},
      {:httpoison, "~> 1.7", override: true},
      {:hackney,
       git: "https://github.com/SergeTupchiy/hackney", ref: "2bf38f92f647de00c4850202f37d4eaab93ed834", override: true},
      {:ex_plasma,
       git: "https://github.com/omgnetwork/ex_plasma", ref: "5e94c4fc82dbf26cb457b30911505ec45ec534ea", override: true},
      {:ex_secp256k1, "~> 0.1.2"},
      {:telemetry, "~> 0.4.1"},
      {:fake_server, "~> 2.1", only: :test},
      {:watcher_info_api, in_umbrella: true},
      {:watcher_security_critical_api, in_umbrella: true},
      {:childchain_api, in_umbrella: true}
    ]
  end
end
