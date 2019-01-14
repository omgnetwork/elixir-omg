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

defmodule OMG.Watcher.Web.View.Utxo do
  @moduledoc """
  The utxo view for rendering json
  """

  use OMG.Watcher.Web, :view

  alias OMG.API.Utxo
  alias OMG.Watcher.DB
  alias OMG.Watcher.Web.Serializer

  require Utxo

  def render("utxo_exit.json", %{utxo_exit: utxo_exit}) do
    utxo_exit
    |> Serializer.Response.serialize(:success)
  end

  def render("utxos.json", %{utxos: utxos}) do
    utxos
    |> Enum.map(&to_view/1)
    |> Serializer.Response.serialize(:success)
  end

  defp to_view(%DB.TxOutput{} = db_entry) do
    view =
      db_entry
      |> Map.take([:amount, :currency, :blknum, :txindex, :oindex, :owner])

    view
    |> Map.put(:utxo_pos, Utxo.position(view.blknum, view.txindex, view.oindex) |> Utxo.Position.encode())
  end
end
