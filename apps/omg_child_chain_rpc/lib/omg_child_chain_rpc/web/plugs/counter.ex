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

defmodule OMG.ChildChainRPC.Plugs.Counter do
  @moduledoc """
  Counts OK vs ERRORED transactions
  """

  alias OMG.Utils.HttpRPC.Error

  alias OMG.Status.Metric.Datadog
  import Plug.Conn

  use GenServer

  ###
  ### PLUG
  ###
  def init(options), do: options

  def call(conn, _params) do
    register_before_send(conn, fn conn ->
      case Map.get(conn.assigns, :response) do
        nil -> Datadog.increment("transaction.submit.error", 1)
        _ -> Datadog.increment("transaction.submit.ok", 1)
      end

      conn
    end)
  end
end
