defmodule OMG.Eth.MixProject do
  use Mix.Project

  require Logger

  def project do
    [
      app: :omg_eth,
      version: OMG.Umbrella.MixProject.umbrella_version(),
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
      env: [
        child_block_interval: 1000
      ],
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:ex_abi, "~> 0.2.0"},
      {:ethereumex, "~> 0.5.2"},
      {:exexec, git: "https://github.com/pthomalla/exexec.git", branch: "add_streams", runtime: true},
      {:briefly, "~> 0.3", only: [:dev, :test]},
      {:deferred_config, "~> 0.1.1"},
      {
        :plasma_contracts,
        # NOTE: this is a long-running patch-branch applied to `master` which hard-codes shorter exit periods.
        #       Rebase on `master`, if new changes are pushed there.
        #       Switch back to `master`, after the exit periods are properly parametrized on deployment
        git: "https://github.com/omisego/plasma-contracts",
        branch: "master",
        sparse: "contracts/",
        compile: contracts_compile(),
        app: false,
        only: [:dev, :test]
      },
      {:appsignal, "~> 1.0"}
    ]
  end

  defp contracts_compile do
    current_path = File.cwd!()
    mixfile_path = __DIR__
    contracts_dir = "deps/plasma_contracts/contracts"

    # NOTE: `solc` needs the relative paths to contracts (`contract_paths`) to be short, hence we need to `cd`
    #       deeply into where the sources are (`compilation_path`)
    compilation_path = Path.join([mixfile_path, "../..", contracts_dir])

    contract_paths =
      ["RootChain.sol", "MintableToken.sol"]
      |> Enum.join(" ")

    output_path = Path.join([mixfile_path, "../..", "_build/contracts"])

    [
      "cd #{compilation_path}",
      "solc #{contract_paths} --overwrite --abi --bin --optimize --optimize-runs 1 -o #{output_path}",
      "cd #{current_path}"
    ]
    |> Enum.join(" && ")
  end
end
