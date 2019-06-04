# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherRPC.Web.View.Transaction do
  @moduledoc """
  The transaction view for rendering json
  """

  alias OMG.Utils.HttpRPC.Response

  use OMG.WatcherRPC.Web, :view

  def render("transaction.json", %{response: transaction}) do
    transaction
    |> render_transaction()
    |> Response.serialize()
  end

  def render("transactions.json", %{response: transactions}) do
    transactions
    |> Enum.map(&render_tx_digest/1)
    |> Response.serialize()
  end

  def render("submission.json", %{response: transaction}) do
    transaction
    |> Response.serialize()
  end

  def render("create.json", %{response: advice}) do
    transactions =
      advice.transactions
      |> Enum.map(fn tx -> Map.update!(tx, :inputs, &render_txoutputs/1) end)

    advice
    |> Map.put(:transactions, transactions)
    |> Response.serialize()
  end

  defp render_transaction(transaction) do
    transaction
    |> Map.take([:txindex, :txhash, :block, :inputs, :outputs, :txbytes, :metadata])
    |> Map.update!(:inputs, &render_txoutputs/1)
    |> Map.update!(:outputs, &render_txoutputs/1)
  end

  defp render_tx_digest(transaction) do
    outputs = Map.fetch!(transaction, :outputs)

    transaction
    |> Map.take([:txindex, :block, :txhash, :metadata])
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
    |> Enum.map(&to_utxo/1)
  end
end
