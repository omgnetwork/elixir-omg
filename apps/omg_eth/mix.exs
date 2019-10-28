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
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:ex_abi, "~> 0.2.1"},
      {:ethereumex, "~> 0.5.5"},
      {
        :plasma_contracts,
        git: "https://github.com/omisego/plasma-contracts",
        branch: "master",
        sparse: "plasma_framework/contracts/",
        compile:
          contracts_compile("plasma_contracts", [
            "plasma_framework/contracts/src/framework/PlasmaFramework.sol",
            "plasma_framework/contracts/src/vaults/verifiers/EthDepositVerifier.sol",
            "plasma_framework/contracts/src/vaults/verifiers/Erc20DepositVerifier.sol",
            "plasma_framework/contracts/src/vaults/EthVault.sol",
            "plasma_framework/contracts/src/vaults/Erc20Vault.sol",
            "plasma_framework/contracts/src/exits/payment/controllers/PaymentStartStandardExit.sol",
            "plasma_framework/contracts/src/exits/payment/controllers/PaymentChallengeStandardExit.sol",
            "plasma_framework/contracts/src/exits/payment/controllers/PaymentProcessStandardExit.sol",
            "plasma_framework/contracts/src/exits/payment/controllers/PaymentStartInFlightExit.sol",
            "plasma_framework/contracts/src/exits/payment/controllers/PaymentPiggybackInFlightExit.sol",
            "plasma_framework/contracts/src/exits/payment/controllers/PaymentChallengeIFENotCanonical.sol",
            "plasma_framework/contracts/src/exits/payment/controllers/PaymentChallengeIFEInputSpent.sol",
            "plasma_framework/contracts/src/exits/payment/controllers/PaymentProcessInFlightExit.sol",
            "plasma_framework/contracts/src/exits/payment/controllers/PaymentChallengeIFEOutputSpent.sol",
            "plasma_framework/contracts/src/exits/registries/SpendingConditionRegistry.sol",
            "plasma_framework/contracts/src/exits/registries/OutputGuardHandlerRegistry.sol",
            "plasma_framework/contracts/src/exits/payment/outputGuardHandlers/PaymentOutputGuardHandler.sol",
            "plasma_framework/contracts/src/exits/payment/PaymentTransactionStateTransitionVerifier.sol",
            "plasma_framework/contracts/src/exits/utils/TxFinalizationVerifier.sol",
            "plasma_framework/contracts/src/exits/payment/PaymentExitGame.sol",
            "plasma_framework/contracts/src/exits/payment/spendingConditions/PaymentOutputToPaymentTxCondition.sol",
            "plasma_framework/contracts/mocks/transactions/eip712Libs/PaymentEip712LibMock.sol"
          ]),
        app: false,
        only: [:dev, :test]
      },
      {
        :openzeppelin_solidity,
        git: "https://github.com/OpenZeppelin/openzeppelin-solidity",
        tag: "v2.3.0",
        compile: contracts_compile("openzeppelin_solidity", ["contracts/token/ERC20/ERC20Mintable.sol"]),
        app: false,
        only: [:dev, :test]
      },
      # Umbrella
      {:omg_bus, in_umbrella: true},
      {:omg_status, in_umbrella: true},
      {:omg_utils, in_umbrella: true},
      # TEST ONLY
      {:exexec,
       git: "https://github.com/pthomalla/exexec.git", branch: "add_streams", only: [:dev, :test], runtime: false},
      {:briefly, "~> 0.3.0", only: [:dev, :test], runtime: false},
      {:exvcr, "~> 0.10", only: :test},
      {:websockex, "~> 0.4.2"},
      # Used for mocking websocket servers
      {:plug_cowboy, "~> 1.0", only: [:dev, :test]}
    ]
  end

  defp contracts_compile(contracts_subdir, contract_paths) do
    current_path = File.cwd!()
    mixfile_path = __DIR__
    contracts_dir = "deps"

    compilation_path = Path.join([mixfile_path, "../..", contracts_dir])
    contract_paths = contract_paths |> Enum.map(&Path.join(contracts_subdir, &1)) |> Enum.join(" ")

    output_path = Path.join([mixfile_path, "../..", "_build/contracts"])

    [
      "cd #{compilation_path}",
      "solc openzeppelin-solidity=openzeppelin_solidity #{contract_paths} --overwrite --abi --bin --optimize --optimize-runs 1 -o #{
        output_path
      }",
      "cd #{current_path}"
    ]
    |> Enum.join(" && ")
  end
end
