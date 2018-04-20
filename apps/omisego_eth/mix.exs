defmodule OmiseGO.Eth.MixProject do
  use Mix.Project

  def project do
    [
      app: :omisego_eth,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:abi, git: "https://github.com/omisego/abi.git", branch: "add_bytes32"},
      {:ethereumex, git: "https://github.com/omisego/ethereumex.git", branch: "personal__api", override: true},
      {:temp, "~> 0.4"},
      {:porcelain, "~> 2.0"}
    ]
  end
end
