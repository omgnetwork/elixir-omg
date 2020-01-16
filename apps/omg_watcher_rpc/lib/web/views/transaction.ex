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

defmodule OMG.WatcherRPC.Web.View.Transaction do
  @moduledoc """
  The transaction view for rendering json
  """

  alias OMG.Utils.HttpRPC.Response
  alias OMG.Utils.Paginator

  use OMG.WatcherRPC.Web, :view

  def render("transaction.json", %{response: transaction, app_infos: app_infos}) do
    transaction
    |> render_transaction()
    |> Response.serialize()
    |> Response.add_app_infos(app_infos)
  end

  def render("transactions.json", %{
        response: %Paginator{data: transactions, data_paging: data_paging},
        app_infos: app_infos
      }) do
    transactions
    |> Enum.map(&render_transaction/1)
    |> Response.serialize_page(data_paging)
    |> Response.add_app_infos(app_infos)
  end

  def render("submission.json", %{response: transaction, app_infos: app_infos}) do
    transaction
    |> Response.serialize()
    |> Response.add_app_infos(app_infos)
  end

  def render("create.json", %{response: advice, app_infos: app_infos}) do
    transactions =
      advice.transactions
      |> Enum.map(fn tx -> Map.update!(tx, :inputs, &render_txoutputs/1) end)
      |> Enum.map(&skip_hex_encoding/1)

    advice
    |> Map.put(:transactions, transactions)
    |> Response.serialize()
    |> Response.add_app_infos(app_infos)
  end

  defp render_transaction(transaction) do
    transaction
    |> Map.take([:txindex, :txhash, :block, :inputs, :outputs, :txbytes, :metadata])
    |> Map.update!(:inputs, &render_txoutputs/1)
    |> Map.update!(:outputs, &render_txoutputs/1)
  end

  defp render_txoutputs(inputs) do
    inputs
    |> Enum.map(&to_utxo/1)
  end

  defp skip_hex_encoding(%{typed_data: typed_data} = tx) do
    typed_data_esc =
      typed_data
      |> Kernel.put_in([:skip_hex_encode], [:types, :primaryType])
      |> Kernel.put_in([:domain, :skip_hex_encode], [:name, :version])

    %{tx | typed_data: typed_data_esc}
  end
end
