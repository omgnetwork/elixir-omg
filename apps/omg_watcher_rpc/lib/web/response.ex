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

defmodule OMG.WatcherRPC.Web.Response do
  @moduledoc """
  Prepares the response into the expected result/data format.

  Contains only the behaviours specific to the watcher.
  For the generic response, see `OMG.Utils.HttpRPC.Response`.
  """

  @app :omg_watcher_rpc

  @doc """
  Adds "version" and "service_name" to the response map.
  """
  @spec add_app_infos(map()) :: %{version: String.t(), service_name: String.t()}
  def add_app_infos(response) do
    response
    |> Map.put(:version, version())
    |> Map.put(:service_name, service_name())
  end

  defp version() do
    OMG.Utils.HttpRPC.Response.version(@app)
  end

  defp service_name() do
    # Configurable through OMG.WatcherRPC.ReleaseTasks.SetApiServiceName
    Application.get_env(@app, :api_service_name)
  end
end
