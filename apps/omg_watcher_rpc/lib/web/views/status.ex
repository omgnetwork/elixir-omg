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

defmodule OMG.WatcherRPC.Web.View.Status do
  @moduledoc """
  The status view for rendering json
  """

  use OMG.WatcherRPC.Web, :view
  alias OMG.Utils.HttpRPC.Response
  alias OMG.WatcherRPC.Web.Response, as: WatcherRPCResponse

  def render("status.json", %{response: status}) do
    status
    |> format_byzantine_events()
    |> Response.serialize()
    |> WatcherRPCResponse.add_app_infos()
  end

  defp format_byzantine_events(%{byzantine_events: byzantine_events, services_synced_heights: heights} = status) do
    prepared_events = Enum.map(byzantine_events, &format_byzantine_event/1)
    prepared_heights = Enum.map(heights, &format_synced_height/1)

    %{status | byzantine_events: prepared_events, services_synced_heights: prepared_heights}
  end

  defp format_byzantine_event(%{name: name} = event) do
    %{event: name, details: event}
  end

  defp format_synced_height({name, height}) do
    %{service: name, height: height}
  end
end
