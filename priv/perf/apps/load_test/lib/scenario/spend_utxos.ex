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

defmodule OMG.Perf.Scenario.SpendUtxos do
  @moduledoc """
  Repeatedly spend an utxo in a transaction with a single output which is then spent again
  """

  use Chaperon.Scenario

  alias Chaperon.Session
  alias Chaperon.Timing
  alias ExPlasma.Utxo

  @eth <<0::160>>

  def run(session) do
    fee_wei = Application.fetch_env!(:load_test, :fee_wei)
    session = Session.assign(session, fee_wei: fee_wei)

    sender = config(session, [:sender])
    transactions_per_session = config(session, [:transactions_per_session])

    repeat(session, :submit_transaction, [sender], transactions_per_session)
  end

  def submit_transaction(session, sender) do
    last_change = session.assigned.last_change
    fee_wei = session.assigned.fee_wei
    {inputs, outputs = [%{amount: change}]} = create_transaction(sender, last_change, fee_wei)

    start = Timing.timestamp()
    {:ok, blknum, txindex} = OMG.Perf.Utils.ChildChain.submit_tx(inputs, outputs, [sender])

    session =
      Chaperon.Session.add_metric(
        session,
        {:call, {OMG.Perf.Scenario.SpendUtxos, "ChildChainAPI.Api.Transaction.submit"}},
        Timing.timestamp() - start
      )

    last_change = %{blknum: blknum, txindex: txindex, oindex: 0, amount: change}
    Chaperon.Session.assign(session, last_change: last_change)
  end

  defp create_transaction(sender, prev_change, fee_wei) do
    change = prev_change.amount - fee_wei
    input = %Utxo{blknum: prev_change.blknum, txindex: prev_change.txindex, oindex: prev_change.oindex}
    change_output = %Utxo{owner: sender.addr, currency: @eth, amount: change}

    {[input], [change_output]}
  end
end
