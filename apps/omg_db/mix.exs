defmodule OMG.DB.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_db,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.7.2",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      env: [
        leveldb_path: Path.join([System.get_env("HOME"), ".omg/data"]),
        server_module: OMG.DB.LevelDBServer,
        server_name: OMG.DB.LevelDBServer
      ],
      extra_applications: [:logger],
      mod: {OMG.DB.Application, []}
    ]
  end

  defp deps do
    [
      # version caused by dependency in merkle_patricia_tree from blockchain
      {:exleveldb, "~> 0.11"},
      {:briefly, "~> 0.3", only: [:dev, :test]}
    ]
  end
end
