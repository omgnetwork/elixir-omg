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

defmodule OMG.Watcher.Web.Controller.Status do
  @moduledoc """
  Module provides operation related to the child chain health status, like: geth syncing status, last minned block
  number and time and last block verified by watcher.
  """

  use OMG.Watcher.Web, :controller

  alias OMG.Watcher.API

  @doc """
  Gets plasma network and Watcher status
  """
  def get_status(conn, _params) do
    API.Status.get_status()
    |> api_response(conn, :status)
  end
end
