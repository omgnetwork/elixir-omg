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

defmodule OMG.WatcherRPC.Web.View.Deposit do
  @moduledoc """
  The deposit view for rendering JSON.
  """

  alias OMG.Utils.HttpRPC.Response
  alias OMG.Utils.Paginator
  alias OMG.WatcherRPC.Web.Response, as: WatcherRPCResponse

  use OMG.WatcherRPC.Web, :view

  def render("deposits.json", %{response: %Paginator{data: ethevents, data_paging: data_paging}}) do
    ethevents
    |> Enum.map(&render_ethevent/1)
    |> Response.serialize_page(data_paging)
    |> WatcherRPCResponse.add_app_infos()
  end

  defp render_ethevent(event) do
    event
    |> Map.update!(:txoutputs, &render_txoutputs/1)
    |> Map.take([
      :eth_height,
      :event_type,
      :log_index,
      :root_chain_txhash,
      :txoutputs,
      :inserted_at,
      :updated_at
    ])
  end

  defp render_txoutputs(outputs) do
    outputs
    |> Enum.map(&to_utxo/1)
  end
end
