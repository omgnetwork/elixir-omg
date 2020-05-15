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
defmodule StandardExitsTests do
  use Cabbage.Feature, async: false, file: "standard_exits.feature"

  require Logger

  alias Itest.Account
  alias Itest.Client
  alias Itest.StandardExitClient
  alias Itest.Transactions.Currency

  setup do
    [{alice_account, alice_pkey}] = Account.take_accounts(1)
    {:ok, _} = Currency.mint_erc20(alice_account, 100)

    %{alice_account: alice_account, alice_pkey: alice_pkey, gas: 0}
  end

  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" (?<symbol>[\w]+) to the root chain$/,
          %{amount: amount, symbol: symbol},
          %{alice_account: alice_account} = state do
    initial_balance = Itest.Poller.eth_get_balance(alice_account)
    currency = get_currency(symbol)

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(alice_account, Itest.PlasmaFramework.vault(currency))

    gas_used = Client.get_gas_used(receipt_hash)

    {_, new_state} =
      Map.get_and_update!(state, :gas, fn current_gas ->
        {current_gas, current_gas + gas_used}
      end)

    balance_after_deposit = Itest.Poller.eth_get_balance(alice_account)

    state = Map.put_new(new_state, :alice_ethereum_balance, balance_after_deposit)
    {:ok, Map.put_new(state, :alice_initial_balance, initial_balance)}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" (?<symbol>[\w]+) on the child chain$/,
          %{amount: amount, symbol: symbol},
          %{alice_account: alice_account} = state do
    expecting_amount = Currency.to_wei(amount)
    _currency = get_currency(symbol)

    balance = Client.get_balance(alice_account, expecting_amount)

    balance = balance["amount"]
    assert_equal(expecting_amount, balance, "For #{alice_account}")
    {:ok, state}
  end

  defwhen ~r/^Alice starts a standard exit on the child chain$/, _, state do
    se = StandardExitClient.start_standard_exit(state.alice_account)
    state = Map.put_new(state, :standard_exit, se)

    {:ok, state}
  end

  defthen ~r/^Alice should no longer see the exiting utxo on the child chain$/, _, state do
    assert Itest.Poller.utxo_absent?(state.alice_account, state.standard_exit.utxo.utxo_pos)
    assert Itest.Poller.exitable_utxo_absent?(state.alice_account, state.standard_exit.utxo.utxo_pos)
  end

  defwhen ~r/^Alice processes the standard exit on the child chain$/, _, state do
    se = StandardExitClient.wait_and_process_standard_exit(state.standard_exit)
    state = Map.put_new(state, :standard_exit_total_gas_used, se.total_gas_used)

    {:ok, state}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" (?<symbol>[\w]+) on the child chain after finality margin$/,
          %{amount: amount, symbol: symbol},
          %{alice_account: alice_account} = state do
    _currency = get_currency(symbol)

    case amount do
      "0" ->
        assert Client.get_balance(alice_account, Currency.to_wei(amount)) == []

      _ ->
        %{"amount" => network_amount} = Client.get_balance(alice_account, Currency.to_wei(amount))
        assert network_amount == Currency.to_wei(amount)
    end

    balance = Itest.Poller.eth_get_balance(alice_account)
    {:ok, Map.put(state, :alice_ethereum_balance, balance)}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" (?<symbol>[\w]+) on the root chain$/,
          %{amount: amount, symbol: symbol},
          %{
            alice_account: _alice_account,
            alice_initial_balance: alice_initial_balance,
            alice_ethereum_balance: alice_ethereum_balance
          } = state do
    _currency = get_currency(symbol)
    gas_wei = state[:standard_exit_total_gas_used] + state[:gas]

    assert_equal(alice_ethereum_balance, alice_initial_balance - gas_wei)
    assert_equal(alice_ethereum_balance, Currency.to_wei(amount) - gas_wei)
    {:ok, state}
  end

  defp assert_equal(left, right) do
    assert_equal(left, right, "")
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end

  defp get_currency("ETH"), do: Currency.ether()
  defp get_currency("ERC20"), do: Currency.erc20()
  defp get_currency(symbol), do: raise "Unrecognized currency: #{symbol}"
end
