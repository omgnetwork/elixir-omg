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

  def render("transaction.json", %{response: transaction}) do
    transaction
    |> render_transaction()
    |> OMG.RPC.Web.Response.serialize()
  end

  def render("transactions.json", %{response: transactions}) do
    transactions
    |> Enum.map(&render_tx_digest/1)
    |> OMG.RPC.Web.Response.serialize()
  end

  defp render_transaction(transaction) do
    transaction
    |> Map.take([:txindex, :txhash, :block, :inputs, :outputs, :txbytes])
    |> Map.update!(:inputs, &render_txoutputs/1)
    |> Map.update!(:outputs, &render_txoutputs/1)
  end

  defp render_tx_digest(transaction) do
    outputs = Map.fetch!(transaction, :outputs)

    transaction
    |> Map.take([:txindex, :block, :txhash])
    |> Map.put(:results, digest_outputs(outputs))
  end

  # calculates results being sums of outputs grouped by currency
  # NOTE: this could be potentially digested by the SQL engine, but choosing here for readability
  defp digest_outputs(outputs) do
    outputs
    |> Enum.group_by(&Map.get(&1, :currency))
    |> Enum.map(&digest_for_currency/1)
  end

  defp digest_for_currency({currency, outputs}) do
    %{currency: currency, value: outputs |> Enum.map(&Map.get(&1, :amount)) |> Enum.sum()}
  end

  defp render_txoutputs(inputs) do
    inputs
    |> Enum.map(&Map.take(&1, [:amount, :blknum, :txindex, :oindex, :currency, :owner]))
  end
end
