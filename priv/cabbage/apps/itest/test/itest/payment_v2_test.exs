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

defmodule PaymentV2Test do
  use Cabbage.Feature, async: true, file: "payment_v2.feature"

  alias Itest.Account

  alias Itest.Client
  alias Itest.StandardExitClient
  alias Itest.Transactions.Currency

  @payment_v2_tx_type 2

  setup do
    [alice, bob] =
      Enum.map(
        Account.take_accounts(2),
        fn {account, pkey} -> %{account: account, pkey: pkey} end
      )

    %{alice: alice, bob: bob}
  end

  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" ETH to the root chain$/,
          %{amount: amount},
          %{alice: alice} = state do
    {:ok, _receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(alice.account, Itest.PlasmaFramework.vault(Currency.ether()))

    {:ok, state}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          %{alice: alice} = state do
    expecting_amount = Currency.to_wei(amount)
    balance = Client.get_exact_balance(alice.account, expecting_amount)["amount"] || 0

    assert_equal(expecting_amount, balance, "For #{alice.account}")

    {:ok, state}
  end

  defwhen ~r/^Alice sends Bob "(?<amount>[^"]+)" ETH on the child chain with payment v1$/,
          %{amount: amount},
          %{alice: alice, bob: bob} = state do
    {:ok, [sign_hash, typed_data, _txbytes]} =
      Client.create_transaction(
        Currency.to_wei(amount),
        alice.account,
        bob.account
      )

    _ = Client.submit_transaction(typed_data, sign_hash, [alice.pkey])

    {:ok, state}
  end

  defwhen ~r/^Alice sends Bob "(?<amount>[^"]+)" ETH on the child chain with payment v2$/,
          %{amount: amount},
          %{alice: alice, bob: bob} = state do
    {:ok, [sign_hash, typed_data, _txbytes]} =
      Client.create_transaction(
        Currency.to_wei(amount),
        alice.account,
        bob.account,
        Currency.ether(),
        @payment_v2_tx_type
      )

    _ = Client.submit_transaction(typed_data, sign_hash, [alice.pkey])

    {:ok, state}
  end

  defthen ~r/^Bob should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          %{bob: bob} = state do
    expecting_amount = Currency.to_wei(amount)

    balance = Client.get_exact_balance(bob.account, expecting_amount)["amount"] || 0

    assert_equal(expecting_amount, balance, "For Bob: #{bob.account}")

    {:ok, state}
  end

  defwhen ~r/^Bob starts a standard exit with the payment v2 output$/, _, %{bob: bob} = state do
    se = StandardExitClient.start_standard_exit(bob.account, @payment_v2_tx_type)
    state = Map.put_new(state, :standard_exit, se)

    {:ok, state}
  end

  defthen ~r/^Bob should no longer see the exiting utxo on the child chain$/, _, %{bob: bob} = state do
    assert Itest.Poller.utxo_absent?(bob.account, state.standard_exit.utxo.utxo_pos)
    assert Itest.Poller.exitable_utxo_absent?(bob.account, state.standard_exit.utxo.utxo_pos)
    {:ok, state}
  end

  defwhen ~r/^Alice processes the standard exit on the child chain$/, _, state do
    StandardExitClient.wait_and_process_standard_exit(state.standard_exit)
    {:ok, state}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the child chain after finality margin$/,
          %{amount: amount},
          state do
    case amount do
      "0" ->
        assert Client.get_exact_balance(state.alice_account, Currency.to_wei(amount), Currency.ether()) == nil

      _ ->
        %{"amount" => network_amount} = Client.get_exact_balance(state.alice_account, Currency.to_wei(amount), currency)
        assert network_amount == Currency.to_wei(amount)
    end
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end
end
