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

  defgiven ~r/^(?<user>[\w]+) has an ethereum account$/, %{user: user}, state do
    [{account, pkey}] = Account.take_accounts(1)
    {:ok, Map.put(state, user, %{account: account, pkey: pkey})}
  end

  defwhen ~r/^(?<user>[\w]+) deposits "(?<amount>[^"]+)" ETH to the root chain$/,
          %{user: user, amount: amount},
          state do
    user = state[user]

    {:ok, _receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(user.account, Itest.PlasmaFramework.vault(Currency.ether()))

    {:ok, state}
  end

  defthen ~r/^(?<user>[\w]+) should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{user: user, amount: amount},
          state do
    user = state[user]
    expecting_amount = Currency.to_wei(amount)
    balance = Client.get_exact_balance(user.account, expecting_amount)["amount"] || 0

    assert_equal(expecting_amount, balance, "For #{user.account}")

    {:ok, state}
  end

  defwhen ~r/^(?<sender>[\w]+) sends (?<receiver>[\w]+) "(?<amount>[^"]+)" ETH on the child chain with payment v1$/,
          %{sender: sender, receiver: receiver, amount: amount},
          state do
    sender = state[sender]
    receiver = state[receiver]

    {:ok, [sign_hash, typed_data, _txbytes]} =
      Client.create_transaction(
        Currency.to_wei(amount),
        sender.account,
        receiver.account
      )

    _ = Client.submit_transaction(typed_data, sign_hash, [sender.pkey])

    {:ok, state}
  end

  defwhen ~r/^(?<sender>[\w]+) sends (?<receiver>[\w]+) "(?<amount>[^"]+)" ETH on the child chain with payment v2$/,
          %{sender: sender, receiver: receiver, amount: amount},
          state do
    sender = state[sender]
    receiver = state[receiver]

    {:ok, [sign_hash, typed_data, _txbytes]} =
      Client.create_transaction(
        Currency.to_wei(amount),
        sender.account,
        receiver.account,
        Currency.ether(),
        @payment_v2_tx_type
      )

    _ = Client.submit_transaction(typed_data, sign_hash, [sender.pkey])

    {:ok, state}
  end

  defwhen ~r/^(?<user>[\w]+) starts a standard exit with the payment v2 output$/, %{user: user}, state do
    user = state[user]
    se = StandardExitClient.start_standard_exit(user.account, @payment_v2_tx_type)
    state = Map.put_new(state, :standard_exit, se)

    {:ok, state}
  end

  defthen ~r/^(?<user>[\w]+) should no longer see the exiting utxo on the child chain$/, %{user: user}, state do
    user = state[user]
    assert Itest.Poller.utxo_absent?(user.account, state.standard_exit.utxo.utxo_pos)
    assert Itest.Poller.exitable_utxo_absent?(user.account, state.standard_exit.utxo.utxo_pos)
    {:ok, state}
  end

  defwhen ~r/^Somebody processes the standard exit on the child chain$/, _, state do
    StandardExitClient.wait_and_process_standard_exit(state.standard_exit)
    {:ok, state}
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end
end
