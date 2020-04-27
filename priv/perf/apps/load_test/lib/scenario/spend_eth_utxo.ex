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

defmodule LoadTest.Scenario.SpendEthUtxo do
  @moduledoc """
  Spends a utxo in a transaction. Can be done repeatedly by setting `transactions_per_session`
  Returns the first output of the spent transaction in the session. Normally this will be the change output.
  """

  use Chaperon.Scenario

  alias Chaperon.Session
  alias Chaperon.Timing

  def run(session) do
    fee_wei = Application.fetch_env!(:load_test, :fee_wei)

    sender = config(session, [:sender])
    receiver = config(session, [:receiver])
    amount = config(session, [:amount], nil)
    delay = config(session, [:transaction_delay], 0)
    transactions_per_session = config(session, [:transactions_per_session])

    repeat(session, :submit_transaction, [amount, fee_wei, sender, receiver, delay], transactions_per_session)
  end

  def submit_transaction(session, nil, fee_wei, sender, receiver, delay) do
    utxo = session.assigned.utxo
    amount = utxo.amount - fee_wei
    submit_transaction(session, amount, fee_wei, sender, receiver, delay)
  end

  def submit_transaction(session, amount, fee_wei, sender, receiver, delay) do
    Process.sleep(delay)
    utxo = session.assigned.utxo
    start = Timing.timestamp()

    [next_utxo | _] = LoadTest.ChildChain.Transaction.spend_eth_utxo(utxo, amount, fee_wei, sender, receiver)

    session
    |> Session.assign(utxo: next_utxo)
    |> Session.add_metric(
      {:call, {LoadTest.Scenario.SpendUtxos, "submit_transaction"}},
      Timing.timestamp() - start
    )
  end
end
