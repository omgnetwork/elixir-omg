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

defmodule LoadTest.Scenario.CreateUtxos do
  @moduledoc """
  Creates utxos owned by a sender provided in scenario config.
  """

  use Chaperon.Scenario

  alias Chaperon.Session
  alias ExPlasma.Utxo
  alias LoadTest.Service.Faucet

  @eth <<0::160>>
  @spawned_outputs_per_transaction 3

  @spec run(Chaperon.Session.t()) :: Chaperon.Session.t()
  def run(session) do
    fee_wei = Application.fetch_env!(:load_test, :fee_wei)
    session = Session.assign(session, fee_wei: fee_wei)

    sender = config(session, [:sender])
    utxos_to_create_per_session = config(session, [:utxos_to_create_per_session])
    number_of_transactions = div(utxos_to_create_per_session, 3)

    transactions_per_session = config(session, [:transactions_per_session])
    min_final_change = transactions_per_session * fee_wei + 1

    amount_per_utxo = get_amount_per_created_utxo(fee_wei)
    initial_funds = number_of_transactions * fee_wei + utxos_to_create_per_session * amount_per_utxo + min_final_change

    {:ok, {utxo, amount}} = Faucet.fund_child_chain_account(sender, initial_funds, @eth)
    {:ok, %{txindex: txindex, oindex: oindex, blknum: blknum}} = Utxo.new(utxo)

    session
    |> Chaperon.Session.assign(last_change: %{blknum: blknum, txindex: txindex, oindex: oindex, amount: amount})
    |> repeat(:submit_transaction, [sender], number_of_transactions)
  end

  def submit_transaction(session, sender) do
    last_change = session.assigned.last_change
    fee_wei = session.assigned.fee_wei
    {inputs, outputs, change} = create_transaction(sender, last_change, fee_wei)

    {:ok, blknum, txindex} = LoadTest.ChildChain.Transaction.submit_tx(inputs, outputs, [sender])

    last_change = %{blknum: blknum, txindex: txindex, oindex: 3, amount: change}

    Chaperon.Session.assign(session, last_change: last_change)
  end

  defp create_transaction(sender, prev_change, fee_wei) do
    amount_per_utxo = get_amount_per_created_utxo(fee_wei)
    change = prev_change.amount - @spawned_outputs_per_transaction * amount_per_utxo - fee_wei
    input = %Utxo{blknum: prev_change.blknum, txindex: prev_change.txindex, oindex: prev_change.oindex}

    created_output = %Utxo{owner: sender.addr, currency: @eth, amount: amount_per_utxo}
    change_output = %Utxo{owner: sender.addr, currency: @eth, amount: change}

    {[input], List.duplicate(created_output, @spawned_outputs_per_transaction) ++ [change_output], change}
  end

  defp get_amount_per_created_utxo(fee_wei), do: fee_wei + 2
end
