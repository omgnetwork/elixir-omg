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
  use Chaperon.Scenario

  alias Chaperon.Session
  alias ExPlasma.Encoding
  alias LoadTest.Ethereum.Account
  alias LoadTest.Service.Faucet
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
    with {:ok, sender, receiver} <- create_accounts(),
         :ok <- fund_account(session, sender) do
      # :ok <- spend_utxo(session, sender, receiver) do
      Session.add_metric(session, "error_rate", 0)
    else
      error ->
        log_error(session, "#{__MODULE__} failed with #{inspect(error)}")

        session
        |> Session.add_metric("error_rate", 1)
        |> Session.add_error(:error, error)
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
         :ok <- validate_utxo(account, token, initial_amount) do
      {:ok, utxo}
    end
  end

  defp fund_childchain_account(address, amount, token) do
    case Faucet.fund_child_chain_account(address, amount, token) do
      {:ok, utxo} -> {:ok, utxo}
      _ -> :failed_to_fund_childchain_account
    end
  end

  defp fetch_childchain_balance(account, amount: amount, token: token, error: error) do
    childchain_balance = Balance.fetch_balance(account.addr, amount, token)

    case childchain_balance["amount"] do
      ^amount -> :ok
      _ -> error
    end
  end

  defp validate_utxo(account, currency, amount) do
    {:ok, result} = Utxo.get_utxos(account)
    string_account = Encoding.to_hex(account.addr)

    case result["data"] do
      [%{"amount" => ^amount, "currency" => ^currency, "owner" => ^string_account}] -> :ok
      _ -> :invalid_utxos
    end
  end
end
