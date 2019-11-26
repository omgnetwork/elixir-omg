# Copyright 2019 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Support.BundleDeployer do
  @moduledoc """
  Convenience module that performs the entire root chain contract suite (plasma framework + exit games) deployment for
  tests
  """

  alias OMG.Eth
  alias OMG.Eth.TransactionHelper
  alias Support.Deployer
  alias Support.RootChainHelper

  use OMG.Utils.LoggerExt

  @tx_defaults Eth.Defaults.tx_defaults()

  @gas_init_tx 500_000

  #
  # Some contract-dependent constants
  #
  # NOTE tx marker must match values defined in the `omg` app. This doesn't depend on `omg` so can't import from there
  # TODO drying this properly would require moving at least part of the deployment to `omg`. Not ready for this yet
  @payment_tx_marker 1
  @payment_output_type_marker 1
  # `Protocol.MORE_VP()` from `Protocol.sol`
  @morevp_protocol_marker 2
  @eth_vault_number 1
  @erc20_vault_number 2

  # Same `safe_gas_stipend` value as `safeGasStipend` in plasma contracts' config.
  # See: https://github.com/omisego/plasma-contracts/blob/master/plasma_framework/config.js#L18
  @safe_gas_stipend 2300

  @eth Eth.RootChain.eth_pseudo_address()

  import Eth.Encoding, only: [to_hex: 1, int_from_hex: 1]

  def deploy_all(root_path, deployer_addr, authority, min_exit_period_seconds \\ nil) do
    min_exit_period_seconds = get_exit_period(min_exit_period_seconds)

    transact_opts = Keyword.put(@tx_defaults, :gas, @gas_init_tx)

    transactions_before = get_transaction_count(deployer_addr)

    {:ok, txhash, plasma_framework_addr} =
      Deployer.create_new("PlasmaFramework", root_path, deployer_addr,
        min_exit_period_seconds: min_exit_period_seconds,
        authority: authority,
        maintainer: deployer_addr
      )

    {:ok, _} = RootChainHelper.activate_child_chain(authority, %{plasma_framework: plasma_framework_addr})

    {:ok, _, eth_deposit_verifier_addr} =
      Deployer.create_new("EthDepositVerifier", root_path, deployer_addr,
        transaction_type: @payment_tx_marker,
        output_type: @payment_output_type_marker
      )

    {:ok, _, erc20_deposit_verifier_addr} =
      Deployer.create_new("Erc20DepositVerifier", root_path, deployer_addr,
        transaction_type: @payment_tx_marker,
        output_type: @payment_output_type_marker
      )

    {:ok, _, eth_vault_addr} =
      Deployer.create_new("EthVault", root_path, deployer_addr,
        plasma_framework: plasma_framework_addr,
        safe_gas_stipend: @safe_gas_stipend
      )

    {:ok, _, erc20_vault_addr} =
      Deployer.create_new("Erc20Vault", root_path, deployer_addr,
        plasma_framework: plasma_framework_addr,
        safe_gas_stipend: @safe_gas_stipend
      )

    backend = Application.fetch_env!(:omg_eth, :eth_node)

    {:ok, _} =
      TransactionHelper.contract_transact(
        backend,
        deployer_addr,
        eth_vault_addr,
        "setDepositVerifier(address)",
        [eth_deposit_verifier_addr],
        transact_opts
      )

    {:ok, _} =
      TransactionHelper.contract_transact(
        backend,
        deployer_addr,
        plasma_framework_addr,
        "registerVault(uint256,address)",
        [@eth_vault_number, eth_vault_addr],
        transact_opts
      )

    {:ok, _} =
      TransactionHelper.contract_transact(
        backend,
        deployer_addr,
        erc20_vault_addr,
        "setDepositVerifier(address)",
        [erc20_deposit_verifier_addr],
        transact_opts
      )

    {:ok, _} =
      TransactionHelper.contract_transact(
        backend,
        deployer_addr,
        plasma_framework_addr,
        "registerVault(uint256,address)",
        [@erc20_vault_number, erc20_vault_addr],
        transact_opts
      )

    {:ok, _, spending_condition_registry_addr} =
      Deployer.create_new("SpendingConditionRegistry", root_path, deployer_addr, [])

    {:ok, _, output_guard_handler_registry_addr} =
      Deployer.create_new("OutputGuardHandlerRegistry", root_path, deployer_addr, [])

    {:ok, _, payment_output_guard_handler_addr} =
      Deployer.create_new("PaymentOutputGuardHandler", root_path, deployer_addr,
        payment_output_type_marker: @payment_output_type_marker
      )

    {:ok, _, payment_transaction_state_transition_verifier_addr} =
      Deployer.create_new("PaymentTransactionStateTransitionVerifier", root_path, deployer_addr, [])

    {:ok, _} =
      TransactionHelper.contract_transact(
        backend,
        deployer_addr,
        output_guard_handler_registry_addr,
        "registerOutputGuardHandler(uint256,address)",
        [@payment_tx_marker, payment_output_guard_handler_addr],
        transact_opts
      )

    {:ok, _, tx_finalization_verifier_addr} =
      Deployer.create_new("TxFinalizationVerifier", root_path, deployer_addr, [])

    IO.inspect("YOLO")

    {:ok, _, _} =
      Deployer.create_new(
        "PaymentExitGameArgs",
        root_path,
        deployer_addr,
        plasma_framework: plasma_framework_addr,
        eth_vault_id: @eth_vault_number,
        erc20_vault_id: @erc20_vault_number,
        output_guard_handler: output_guard_handler_registry_addr,
        spending_condition: spending_condition_registry_addr,
        payment_transaction_state_transition_verifier: payment_transaction_state_transition_verifier_addr,
        tx_finalization_verifier: tx_finalization_verifier_addr,
        tx_type: @payment_tx_marker,
        safe_gas_stipend: @safe_gas_stipend
      )

    {:ok, _, payment_exit_game_addr} =
      Deployer.create_new(
        "PaymentExitGame",
        root_path,
        deployer_addr,
        plasma_framework: plasma_framework_addr,
        eth_vault_id: @eth_vault_number,
        erc20_vault_id: @erc20_vault_number,
        output_guard_handler: output_guard_handler_registry_addr,
        spending_condition: spending_condition_registry_addr,
        payment_transaction_state_transition_verifier: payment_transaction_state_transition_verifier_addr,
        tx_finalization_verifier: tx_finalization_verifier_addr,
        tx_type: @payment_tx_marker,
        safe_gas_stipend: @safe_gas_stipend
      )

    {:ok, _, payment_output_to_payment_tx_condition_addr} =
      Deployer.create_new(
        "PaymentOutputToPaymentTxCondition",
        root_path,
        deployer_addr,
        plasma_framework: plasma_framework_addr,
        input_tx_type: @payment_tx_marker,
        spending_tx_type: @payment_tx_marker
      )

    {:ok, _} =
      TransactionHelper.contract_transact(
        backend,
        deployer_addr,
        spending_condition_registry_addr,
        "registerSpendingCondition(uint256,uint256,address)",
        [@payment_output_type_marker, @payment_tx_marker, payment_output_to_payment_tx_condition_addr],
        transact_opts
      )

    {:ok, _} =
      TransactionHelper.contract_transact(
        backend,
        deployer_addr,
        plasma_framework_addr,
        "registerExitGame(uint256,address,uint8)",
        [@payment_tx_marker, payment_exit_game_addr, @morevp_protocol_marker],
        transact_opts
      )

    {:ok, _} =
      RootChainHelper.add_exit_queue(1, @eth, %{plasma_framework: plasma_framework_addr})
      |> Support.DevHelper.transact_sync!()

    expected_count_of_transactions = 29
    assert_count_of_mined_transactions(deployer_addr, transactions_before, expected_count_of_transactions)

    {:ok, txhash,
     %{
       plasma_framework: plasma_framework_addr,
       eth_vault: eth_vault_addr,
       erc20_vault: erc20_vault_addr,
       payment_exit_game: payment_exit_game_addr
     }}
  end

  # instead of `transact_sync!()` on every call, we only check if the expected count of txs were mined from the deployer
  defp assert_count_of_mined_transactions(deployer_addr, transactions_before, expected_count) do
    transactions_after = get_transaction_count(deployer_addr)
    count = transactions_after - transactions_before

    if count != expected_count,
      do:
        Logger.warn(
          "Transactions from deployer mined (#{inspect(count)}) differs from the " <>
            "expected (#{inspect(expected_count)}). Check the deployment pipeline for possible failures"
        )
  end

  defp get_transaction_count(deployer_addr) do
    {:ok, transactions_before} = Ethereumex.HttpClient.eth_get_transaction_count(to_hex(deployer_addr))
    int_from_hex(transactions_before)
  end

  defp get_exit_period(nil) do
    Application.fetch_env!(:omg_eth, :min_exit_period_seconds)
  end

  defp get_exit_period(exit_period), do: exit_period
end
