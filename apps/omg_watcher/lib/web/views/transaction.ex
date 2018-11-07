# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.Web.View.Transaction do
  @moduledoc """
  The transaction view for rendering json
  """

  use OMG.Watcher.Web, :view

  alias OMG.API.State.Transaction
  alias OMG.Watcher.Web.Serializer

  def render("transaction.json", %{transaction: transaction}) do
    transaction
    |> render_transaction()
    |> Serializer.Response.serialize(:success)
  end

  def render("transactions.json", %{transactions: transactions}) do
    transactions
    |> Enum.map(&render_transaction/1)
    |> Serializer.Response.serialize(:success)
  end

  def render("transaction_encode.json", %{transaction: transaction}) do
    OMG.API.State.Transaction.encode(transaction)
    |> Serializer.Response.serialize(:success)
  end

  defp render_transaction(transaction) do
    {:ok,
     %Transaction.Signed{
       raw_tx: tx,
       sigs: sigs
     } = signed} = Transaction.Signed.decode(transaction.txbytes)

    {:ok,
     %Transaction.Recovered{
       spenders: spenders
     }} = Transaction.Recovered.recover_from(signed)

    block = transaction.block

    tx_base = %{
      txid: transaction.txhash,
      txblknum: transaction.blknum,
      txindex: transaction.txindex,
      timestamp: block.timestamp,
      eth_height: block.eth_height
    }

    inputs = Transaction.get_inputs(tx)
    outputs = Transaction.get_outputs(tx)

    formatted =
      tx_base
      |> add_inputs(inputs)
      |> add_outputs(outputs)
      |> add_sigs(sigs)
      |> add_spenders(spenders)

    formatted
  end

  defp add_inputs(tx, [input1, input2]) do
    Map.merge(
      tx,
      %{
        blknum1: input1.blknum,
        txindex1: input1.txindex,
        oindex1: input1.oindex,
        blknum2: input2.blknum,
        txindex2: input2.txindex,
        oindex2: input2.oindex
      }
    )
  end

  defp add_outputs(tx, [output1, output2]) do
    Map.merge(
      tx,
      %{
        cur12: output1.currency,
        newowner1: output1.owner,
        amount1: output1.amount,
        newowner2: output2.owner,
        amount2: output2.amount
      }
    )
  end

  defp add_sigs(tx, [sig]), do: Map.merge(tx, %{sig1: sig, sig2: <<>>})
  defp add_sigs(tx, [sig1, sig2]), do: Map.merge(tx, %{sig1: sig1, sig2: sig2})

  defp add_spenders(tx, []), do: Map.merge(tx, %{spender1: nil, spender2: nil})
  defp add_spenders(tx, [spender]), do: Map.merge(tx, %{spender1: spender, spender2: nil})
  defp add_spenders(tx, [spender1, spender2]), do: Map.merge(tx, %{spender1: spender1, spender2: spender2})
end
