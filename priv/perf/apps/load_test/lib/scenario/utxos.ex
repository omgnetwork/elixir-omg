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

defmodule LoadTest.Scenario.Utxos do
  @moduledoc """
  The scenario for utxos tests:

  1. It creates two accounts: the sender and the receiver.
  2. It funds sender with the specified amount on the childchain, checks utxos and balance.
  3. The sender account sends the specifed amount on the childchain to the receiver,
      checks its balance on the childchain and utxos for both accounts.

  """

  use Chaperon.Scenario

  alias Chaperon.Session
  alias ExPlasma.Encoding
  alias LoadTest.ChildChain.Transaction
  alias LoadTest.Ethereum.Account
  alias LoadTest.Service.Faucet
  alias LoadTest.Service.Metrics
  alias LoadTest.WatcherInfo.Balance
  alias LoadTest.WatcherInfo.Utxo

  @spec run(Session.t()) :: Session.t()
  def run(session) do
    tps = config(session, [:run_config, :tps])
    period_in_seconds = config(session, [:run_config, :period_in_seconds])

    total_number_of_transactions = tps * period_in_seconds
    period_in_mseconds = period_in_seconds * 1_000

    session
    |> cc_spread(
      :create_utxos_and_make_assertions,
      total_number_of_transactions,
      period_in_mseconds
    )
    |> await_all(:create_utxos_and_make_assertions)
  end

  def create_utxos_and_make_assertions(session) do
    {_, session} =
      Metrics.run_with_metrics(
        fn ->
          do_create_utxos_and_make_assertions(session)
        end,
        "test"
      )

    session
  end

  defp do_create_utxos_and_make_assertions(session) do
    with {:ok, sender, receiver} <- create_accounts(),
         {:ok, utxo} <- fund_account(session, sender),
         :ok <- spend_utxo(session, utxo, sender, receiver) do
      {:ok, session}
    else
      _ -> {:error, session}
    end
  end

  defp create_accounts() do
    {:ok, sender_address} = Account.new()
    {:ok, receiver_address} = Account.new()

    {:ok, sender_address, receiver_address}
  end

  defp fund_account(session, account) do
    initial_amount = config(session, [:chain_config, :initial_amount])
    token = config(session, [:chain_config, :token])

    with {:ok, utxo} <- fund_childchain_account(account, initial_amount, token),
         :ok <-
           fetch_childchain_balance(account,
             amount: initial_amount,
             token: Encoding.to_binary(token),
             error: :wrong_childchain_after_funding
           ),
         :ok <- validate_utxos(account, %{utxo | owner: account.addr}) do
      {:ok, utxo}
    end
  end

  defp validate_utxos(account, utxo) do
    utxo_with_owner =
      case utxo do
        :empty -> :empty
        _ -> %{utxo | owner: account.addr}
      end

    case Utxo.get_utxos(account, utxo_with_owner) do
      {:ok, _} -> :ok
      _other -> :invalid_utxos
    end
  end

  defp fund_childchain_account(address, amount, token) do
    case Faucet.fund_child_chain_account(address, amount, token) do
      {:ok, utxo} -> {:ok, utxo}
      _ -> :failed_to_fund_childchain_account
    end
  end

  defp spend_utxo(session, utxo, sender, receiver) do
    amount = config(session, [:chain_config, :initial_amount])
    token = config(session, [:chain_config, :token])
    fee = config(session, [:chain_config, :fee])
    amount_to_transfer = amount - fee

    with [new_utxo] <- Transaction.spend_utxo(utxo, amount_to_transfer, fee, sender, receiver, token),
         :ok <- validate_utxos(sender, :empty),
         :ok <- validate_utxos(receiver, %{new_utxo | owner: receiver.addr}),
         :ok <-
           fetch_childchain_balance(sender, amount: 0, token: Encoding.to_binary(token), error: :wrong_sender_balance),
         :ok <-
           fetch_childchain_balance(receiver,
             amount: amount_to_transfer,
             token: Encoding.to_binary(token),
             error: :wrong_sender_balance
           ) do
      :ok
    end
  end

  defp fetch_childchain_balance(account, amount: amount, token: token, error: error) do
    childchain_balance = Balance.fetch_balance(account.addr, amount, token)

    case childchain_balance do
      nil when amount == 0 -> :ok
      %{"amount" => ^amount} -> :ok
      _ -> error
    end
  end
end
