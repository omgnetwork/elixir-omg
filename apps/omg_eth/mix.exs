defmodule OMG.Eth.MixProject do
  use Mix.Project

  require Logger

  def project do
    [
      app: :omg_eth,
      version: "#{String.trim(File.read!("../../VERSION"))}",
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
      mod: {OMG.Eth.Application, []},
      extra_applications: [:sasl, :logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:ex_abi, "~> 0.2.1"},
      {:ethereumex, "~> 0.5.4"},
      {
        :plasma_contracts,
        git: "https://github.com/omisego/plasma-contracts",
        branch: "master",
        sparse: "contracts/",
        compile: contracts_compile(),
        app: false,
        only: [:dev, :test]
      },
      # Umbrella
      {:omg_bus, in_umbrella: true},
      {:omg_status, in_umbrella: true},
      # TEST ONLY
      {:exexec,
       git: "https://github.com/pthomalla/exexec.git", branch: "add_streams", only: [:dev, :test], runtime: false},
      {:briefly, "~> 0.3.0", only: [:dev, :test], runtime: false},
      {:websockex, "~> 0.4.2"},
      {:omg_utils, in_umbrella: true},
      # Used for mocking websocket servers
      {:plug_cowboy, "~> 1.0", only: [:dev, :test]}
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
      ["RootChain.sol", "MintableToken.sol", "SignatureTest.sol"]
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
