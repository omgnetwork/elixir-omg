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

    erc20_amount = Currency.to_wei(100)
    erc20_vault = Itest.PlasmaFramework.vault(Currency.erc20())
    {:ok, mint_receipt} = Currency.mint_erc20(alice_account, erc20_amount)
    {:ok, approve_receipt} = Currency.approve_erc20(alice_account, erc20_amount, erc20_vault)

    gas = Client.get_gas_used(mint_receipt) + Client.get_gas_used(approve_receipt)

    %{alice_account: alice_account, alice_pkey: alice_pkey, gas: gas}
  end

  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" (?<symbol>[\w]+) to the root chain$/,
          %{amount: amount, symbol: symbol},
          %{alice_account: alice_account} = state do
    currency = get_currency(symbol)
    initial_balance = Itest.Poller.root_chain_get_balance(alice_account, currency)

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(alice_account, Itest.PlasmaFramework.vault(currency), currency)

    gas_used = Client.get_gas_used(receipt_hash)

    {_, new_state} =
      Map.get_and_update!(state, :gas, fn current_gas ->
        {current_gas, current_gas + gas_used}
      end)

    balance_after_deposit = Itest.Poller.root_chain_get_balance(alice_account, currency)

    state = Map.put_new(new_state, :alice_ethereum_balance, balance_after_deposit)
    {:ok, Map.put_new(state, :alice_initial_balance, initial_balance)}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" (?<symbol>[\w]+) on the child chain$/,
          %{amount: amount, symbol: symbol},
          %{alice_account: alice_account} = state do
    expecting_amount = Currency.to_wei(amount)
    currency = get_currency(symbol)

    balance = Client.get_exact_balance(alice_account, expecting_amount, currency)

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
          state do
    currency = get_currency(symbol)

    case amount do
      "0" ->
        assert Client.get_exact_balance(state.alice_account, Currency.to_wei(amount), currency) == nil

      _ ->
        %{"amount" => network_amount} = Client.get_exact_balance(state.alice_account, Currency.to_wei(amount), currency)
        assert network_amount == Currency.to_wei(amount)
    end
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" (?<symbol>[\w]+) on the root chain$/,
          %{amount: amount, symbol: symbol},
          state do
    currency = get_currency(symbol)
    ether = Currency.ether()
    eth_balance = Itest.Poller.root_chain_get_balance(state.alice_account, ether)

    case currency do
      ^ether ->
        gas_wei = state.standard_exit_total_gas_used + state.gas
        assert eth_balance == Currency.to_wei(amount) - gas_wei

      _ ->
        erc20_balance = Itest.Poller.root_chain_get_balance(state.alice_account, currency)
        assert erc20_balance == Currency.to_wei(amount) + 1
    end

    {:ok, Map.put(state, :alice_ethereum_balance, eth_balance)}
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end

  defp get_currency("ETH"), do: Currency.ether()
  defp get_currency("ERC20"), do: Currency.erc20()
  defp get_currency(symbol), do: raise("Unrecognized currency: #{symbol}")
end
