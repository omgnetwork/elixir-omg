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

defmodule LoadTest.Scenario.ChildChainSubmitTransactions do
  @moduledoc """
  This scenario tests childchain handling lots of transactions concurrently
  """

  use Chaperon.Scenario

  alias Chaperon.Session
  alias Chaperon.Timing
  alias LoadTest.Ethereum.Account
  alias LoadTest.Service.Faucet

  @eth <<0::160>>

  @spec run(Session.t()) :: Session.t()
  def run(session) do
    fee_wei = Application.fetch_env!(:load_test, :fee_wei)

    # Create a new account and fund it from the faucet
    {:ok, sender} = LoadTest.Ethereum.Account.new()
    ntx_to_send = config(session, [:transactions_per_session])
    initial_funds = ntx_to_send + ntx_to_send * fee_wei
    {:ok, utxo} = Faucet.fund_child_chain_account(sender, initial_funds, @eth)

    session
    |> Session.assign(next_utxo: utxo)
    |> repeat(:submit_transaction, [sender, fee_wei], ntx_to_send)
  end

  def submit_transaction(session, sender, fee_wei) do
    {:ok, receiver} = Account.new()
    start = Timing.timestamp()

    [next_utxo | _] =
      LoadTest.ChildChain.Transaction.spend_eth_utxo(
        session.assigned.next_utxo,
        1,
        fee_wei,
        sender,
        receiver
      )

    session
    |> Session.assign(next_utxo: next_utxo)
    |> log_info("Transaction submitted successfully {#{inspect(next_utxo.blknum)}, #{inspect(next_utxo.txindex)}}")
    |> Session.add_metric(
      {:call, {LoadTest.Scenario.ChildChainSubmitTransactions, "ChildChain.Transaction.submit"}},
      Timing.timestamp() - start
    )
  end
end
