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
  Spends a utxo in a transaction.

  Can be done repeatedly by setting `transactions_per_session`
  Returns the first output of the spent transaction in the session. Normally this will be the change output.

  ## configuration values
  - `sender` the owner of the utxo
  - `receiver` the receiver's account
  - `amount` the amount to spend. If amount + fee is less than the value of the utxo then the change
     will be sent back to the sender
  - `transactions_per_session` the number of transactions to send. Each transaction after the first
     will spend the change output of the previous transaction
  - `transaction_delay` delay in milliseconds before sending the transaction. Used to control the tx rate.
  """

  use Chaperon.Scenario

  alias Chaperon.Session
  alias Chaperon.Timing

  def run(session) do
    fee_amount = Application.fetch_env!(:load_test, :fee_amount)

    sender = config(session, [:sender])
    receiver = config(session, [:receiver])
    amount = config(session, [:amount], nil)
    test_currency = config(session, [:test_currency], nil)
    delay = config(session, [:transaction_delay], 0)
    transactions_per_session = config(session, [:transactions_per_session])

    repeat(
      session,
      :submit_transaction,
      [amount, fee_amount, sender, receiver, test_currency, delay],
      transactions_per_session
    )
  end

  def submit_transaction(session, nil, fee_amount, sender, receiver, currency, delay) do
    utxo = session.assigned.utxo
    amount = utxo.amount - fee_amount
    submit_transaction(session, amount, fee_amount, sender, receiver, currency, delay)
  end

  def submit_transaction(session, amount, fee_amount, sender, receiver, currency, delay) do
    Process.sleep(delay)
    utxo = session.assigned.utxo
    start = Timing.timestamp()

    [next_utxo | _] = LoadTest.ChildChain.Transaction.spend_utxo(utxo, amount, fee_amount, sender, receiver, currency)

    session
    |> Session.assign(utxo: next_utxo)
    |> Session.add_metric(
      {:call, {LoadTest.Scenario.SpendEthUtxo, "submit_transaction"}},
      Timing.timestamp() - start
    )
  end
end
