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

defmodule OMG.ChildChainRPC.Plugs.Health do
  @moduledoc """
  Observes the systems alarms and prevents calls towards an unhealthy one.
  """

  alias OMG.Status
  alias OMG.Utils.HttpRPC.Error
  alias Phoenix.Controller

  import Plug.Conn
  require Logger
  use GenServer

  ###
  ### PLUG
  ###
  def init(options), do: options

  def call(conn, _params) do
    # is anything raised?
    if Status.is_healthy() do
      conn
    else
      data =
        Error.serialize(
          "operation:service_unavailable",
          "The server is not ready to handle the request.",
          conn.assigns.app_infos
        )

      conn
      |> Controller.json(data)
      |> halt()
    end
  end
end
