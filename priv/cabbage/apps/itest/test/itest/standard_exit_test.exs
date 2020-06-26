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
    {:ok, _} = Currency.mint_erc20(alice_account, erc20_amount)
    {:ok, _} = Currency.approve_erc20(alice_account, erc20_amount, erc20_vault)

    %{alice_account: alice_account, alice_pkey: alice_pkey, gas_used: 0}
  end

  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" (?<symbol>[\w]+) to the root chain$/,
          %{amount: amount, symbol: symbol},
          %{alice_account: alice_account} = state do
    currency = get_currency(symbol)

    # We need both initial_eth_balance and initial_balance because in ERC-20 case we check both
    initial_eth_balance = Itest.Poller.root_chain_get_balance(alice_account, Currency.ether())
    initial_balance = Itest.Poller.root_chain_get_balance(alice_account, currency)

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(alice_account, Itest.PlasmaFramework.vault(currency), currency)

    deposit_gas = Client.get_gas_used(receipt_hash)
    balance_after_deposit = Itest.Poller.root_chain_get_balance(alice_account, currency)

    new_state =
      state
      |> Map.put_new(:alice_root_chain_balance, balance_after_deposit)
      |> Map.put_new(:alice_initial_eth_balance, initial_eth_balance)
      |> Map.put_new(:alice_initial_balance, initial_balance)
      |> Map.update!(:gas_used, fn current_gas -> current_gas + deposit_gas end)

    {:ok, new_state}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" (?<symbol>[\w]+) on the child chain$/,
          %{amount: amount, symbol: symbol},
          %{alice_account: alice_account} = state do
    expecting_amount = Currency.to_wei(amount)
    currency = get_currency(symbol)

    balance = Client.get_exact_balance(alice_account, expecting_amount, currency)
    balance = balance["amount"]
    assert expecting_amount == balance, "Expecting #{amount} #{symbol} for #{alice_account}"

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

    state =
      state
      |> Map.put_new(:standard_exit_total_gas_used, se.total_gas_used)
      |> Map.update!(:gas_used, fn gas_used -> gas_used + se.total_gas_used end)

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

  defthen ~r/^Alice should have the original ETH balance minus gas used on the root chain$/, _, state do
    eth_balance = Itest.Poller.root_chain_get_balance(state.alice_account, Currency.ether())
    assert eth_balance == state.alice_initial_eth_balance - state.gas_used

    {:ok, Map.put(state, :alice_root_chain_balance, eth_balance)}
  end

  defthen ~r/^Alice should have the original (?<symbol>[\w]+) balance on the root chain$/,
          %{symbol: symbol},
          state do
    currency = get_currency(symbol)

    erc20_balance = Itest.Poller.root_chain_get_balance(state.alice_account, currency)
    assert erc20_balance == state.alice_initial_balance

    {:ok, Map.put(state, :alice_root_chain_erc20_balance, erc20_balance)}
  end

  defp get_currency("ETH"), do: Currency.ether()
  defp get_currency("ERC20"), do: Currency.erc20()
  defp get_currency(symbol), do: raise("Unrecognized currency: #{symbol}")
end
