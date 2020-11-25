# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule LoadTest.Scenario.CreateUtxos do
  @moduledoc """
  Funds an account and then splits the resulting utxo into many more utxos.

  ## configuration values
  - `sender` the owner of the utxos
  - `utxos_to_create_per_session` the amount of utxos to create
  """

  use Chaperon.Scenario

  alias Chaperon.Session
  alias ExPlasma.Utxo

  @spawned_outputs_per_transaction 3

  @spec run(Session.t()) :: Session.t()
  def run(session) do
    fee_amount = Application.fetch_env!(:load_test, :fee_amount)
    session = Session.assign(session, fee_amount: fee_amount)
    test_currency = Application.fetch_env!(:load_test, :test_currency)
    session = Session.assign(session, test_currency: test_currency)

    sender = config(session, [:sender])
    utxos_to_create_per_session = config(session, [:utxos_to_create_per_session])
    number_of_transactions = div(utxos_to_create_per_session, 3)

    transactions_per_session = config(session, [:transactions_per_session])
    min_final_change = transactions_per_session * fee_amount + 1

    amount_per_utxo = get_amount_per_created_utxo(fee_amount)

    initial_funds =
      number_of_transactions * fee_amount + utxos_to_create_per_session * amount_per_utxo + min_final_change

    session
    |> run_scenario(LoadTest.Scenario.FundAccount, %{
      account: sender,
      initial_funds: initial_funds,
      test_currency: test_currency
    })
    |> repeat(:submit_transaction, [sender], number_of_transactions)
  end

  def submit_transaction(session, sender) do
    {inputs, outputs} =
      create_transaction(
        sender,
        session.assigned.utxo,
        session.assigned.test_currency,
        session.assigned.fee_amount
      )

    new_outputs = LoadTest.ChildChain.Transaction.submit_tx(inputs, outputs, [sender])

    Session.assign(session, utxo: List.last(new_outputs))
  end

  defp create_transaction(sender, input, currency, fee_amount) do
    amount_per_utxo = get_amount_per_created_utxo(fee_amount)
    change = input.amount - @spawned_outputs_per_transaction * amount_per_utxo - fee_amount

    created_output = %Utxo{owner: sender.addr, currency: currency, amount: amount_per_utxo}
    change_output = %Utxo{owner: sender.addr, currency: currency, amount: change}

    {[input], List.duplicate(created_output, @spawned_outputs_per_transaction) ++ [change_output]}
  end

  defp get_amount_per_created_utxo(fee_amount), do: fee_amount + 2
end
