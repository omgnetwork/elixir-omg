defmodule OmiseGO.DB.MixProject do
  use Mix.Project

  def project do
    [
      app: :omisego_db,
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
      env: [
        leveldb_path: Path.join([System.get_env("HOME"), ".omisego/data"]),
        server_module: OmiseGO.DB.LevelDBServer,
        server_name: OmiseGO.DB.LevelDBServer,
      ],
      extra_applications: [:logger],
      mod: {OmiseGO.DB.Application, []}
    ]
  end

  defp deps do
    [
      {:exleveldb, "~> 0.11"}, # version caused by dependency in merkle_patricia_tree from blockchain
    ]
  end
end
