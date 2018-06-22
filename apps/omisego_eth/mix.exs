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
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:abi, git: "https://github.com/omisego/abi.git", branch: "fix_type_encoder"},
      {:ethereumex, git: "https://github.com/omisego/ethereumex.git", branch: "request_timeout", override: true},
      {:exexec, git: "https://github.com/paulperegud/exexec.git", branch: "add_streams", runtime: true},
      {
        :plasma_mvp_contracts,
        git: "https://github.com/purbanow/plasma-mvp",
        branch: "delete_indexed_keyword",
        sparse: "plasma/root_chain/contracts/",
        compile: false,
        app: false,
        only: [:dev, :test]
      }
    ]
  end
end
