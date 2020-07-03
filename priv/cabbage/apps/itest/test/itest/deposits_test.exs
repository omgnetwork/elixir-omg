# Copyright 2019-2020 OmiseGO Pte Ltd
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
defmodule DepositsTests do
  use Cabbage.Feature, async: true, file: "deposits.feature"
  @moduletag :reorg

  require Logger

  alias Itest.Account
  alias Itest.ApiModel.WatcherSecurityCriticalConfiguration
  alias Itest.Client
  alias Itest.Reorg
  alias Itest.Transactions.Currency

  setup do
    [{alice_account, alice_pkey}, {bob_account, _bob_pkey}] = Account.take_accounts(2)

    %{alice_account: alice_account, alice_pkey: alice_pkey, bob_account: bob_account, gas: 0}
  end

  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" ETH to the root chain$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    initial_balance = Itest.Poller.root_chain_get_balance(alice_account)

    {:ok, block_number_before_deposit} = Client.get_latest_block_number()

    {:ok, receipt_hash} =
      Reorg.execute_in_reorg(fn ->
        amount
        |> Currency.to_wei()
        |> Client.deposit(alice_account, Itest.PlasmaFramework.vault(Currency.ether()))
      end)

    gas_used = Client.get_gas_used(receipt_hash)

    {_, new_state} =
      Map.get_and_update!(state, :gas, fn current_gas ->
        {current_gas, current_gas + gas_used}
      end)

    balance_after_deposit = Itest.Poller.root_chain_get_balance(alice_account)

    state =
      new_state
      |> Map.put_new(:alice_ethereum_balance, balance_after_deposit)
      |> Map.put_new(:alice_initial_balance, initial_balance)
      |> Map.put(:block_number_before_deposit, block_number_before_deposit)

    {:ok, state}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          %{
            alice_account: alice_account,
            block_number_before_deposit: block_number_before_deposit
          } = state do
    {:ok, response} =
      WatcherSecurityCriticalAPI.Api.Configuration.configuration_get(WatcherSecurityCriticalAPI.Connection.new())

    watcher_security_critical_config =
      WatcherSecurityCriticalConfiguration.to_struct(Jason.decode!(response.body)["data"])

    finality_margin_blocks = watcher_security_critical_config.deposit_finality_margin
    final_block = block_number_before_deposit + finality_margin_blocks

    :ok = Client.wait_until_block_number(final_block)

    expecting_amount = Currency.to_wei(amount)

    balance = Client.get_balance(alice_account)

    balance = balance["amount"]
    assert_equal(expecting_amount, balance, "For #{alice_account}")
    {:ok, state}
  end

  defwhen ~r/^Alice sends Bob "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          %{alice_account: alice_account, alice_pkey: alice_pkey, bob_account: bob_account} = state do
    {:ok, [sign_hash, typed_data, _txbytes]} =
      Client.create_transaction(
        Currency.to_wei(amount),
        alice_account,
        bob_account
      )

    # Alice needs to sign 2 inputs of 1 Eth, 1 for Bob and 1 for the fees
    _ = Client.submit_transaction(typed_data, sign_hash, [alice_pkey, alice_pkey])

    {:ok, state}
  end

  defthen ~r/^Bob should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          %{bob_account: bob_account} = state do
    balance = Client.get_balance(bob_account)["amount"]
    assert_equal(Currency.to_wei(amount), balance, "For #{bob_account}.")

    {:ok, state}
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end
end
