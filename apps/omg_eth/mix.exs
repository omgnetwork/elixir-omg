defmodule OMG.Eth.MixProject do
  use Mix.Project

  require Logger

  def project do
    [
      app: :omg_eth,
      version: "0.1.0",
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
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:abi, git: "https://github.com/omisego/abi.git", branch: "encode_dynamic_types"},
      {:ethereumex, git: "https://github.com/omisego/ethereumex.git", branch: "request_timeout2", override: true},
      {:exexec, git: "https://github.com/pthomalla/exexec.git", branch: "add_streams", runtime: true},
      # TODO: we only need in :dev and :test here, but we need in :prod too in performance
      #       then there's some unexpected behavior of mix that won't allow to mix these, see
      #       [here](https://elixirforum.com/t/mix-dependency-is-not-locked-error-when-building-with-edeliver/7069/3)
      {:briefly, "~> 0.3"},
      {
        :plasma_contracts,
        git: "https://github.com/omisego/plasma-contracts",
        branch: "develop_3.7_py_solc_simple_indexed_events",
        sparse: "contracts/",
        compile: contracts_compile(),
        app: false,
        only: [:dev, :test]
      }
    ]
  end

  defp contracts_compile do
    mixfile_path = __DIR__
    "cd #{mixfile_path}/../../ && py-solc-simple -i deps/plasma_contracts/contracts/ -o contracts/build/"
  end
end
