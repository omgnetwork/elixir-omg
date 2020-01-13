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

defmodule OMG.WatcherRPC.Web.Controller.Status do
  @moduledoc """
  Module provides operation related to the child chain health status, like: geth syncing status, last minned block
  number and time and last block verified by watcher.
  """

  use OMG.WatcherRPC.Web, :controller
  # check for health before calling action
  plug(OMG.WatcherRPC.Plugs.Health)
  alias OMG.Watcher.API.Status

  @doc """
  Gets plasma network and Watcher status
  """
  def get_status(conn, _params) do
    api_response(Status.get_status(), conn, :status)
  end
end
