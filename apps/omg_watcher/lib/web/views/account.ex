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

defmodule OMG.Watcher.Web.View.Account do
  @moduledoc """
  The account view for rendering json
  """

  use OMG.Watcher.Web, :view

  alias OMG.API.Utxo
  alias OMG.RPC.Web
  require Utxo

  def render("balance.json", %{response: balance}) do
    balance
    |> Web.Response.serialize()
  end

  def render("utxos.json", %{response: utxos}) do
    utxos
    |> Enum.map(&to_view/1)
    |> Web.Response.serialize()
  end

  defp to_view(db_entry) do
    view =
      db_entry
      |> Map.take([:amount, :currency, :blknum, :txindex, :oindex, :owner])

    view
    |> Map.put(:utxo_pos, Utxo.position(view.blknum, view.txindex, view.oindex) |> Utxo.Position.encode())
  end
end
