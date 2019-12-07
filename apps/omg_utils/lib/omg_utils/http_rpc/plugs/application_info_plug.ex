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

defmodule OMG.Utils.HttpRPC.Plugs.ApplicationInfo do
  @moduledoc """
  Assigns per-application meta-information like version and service name to the connection, for later use
  """
  @behaviour Plug

  @sha String.replace(elem(System.cmd("git", ["rev-parse", "--short=7", "HEAD"]), 0), "\n", "")

  def init(options), do: options

  def call(conn, options) do
    conn
    |> Plug.Conn.assign(:app_infos, %{
      version: version(Keyword.fetch!(options, :application)),
      service_name: service_name(Keyword.fetch!(options, :application))
    })
  end

  defp version(application) do
    {:ok, vsn} = :application.get_key(application, :vsn)
    List.to_string(vsn) <> "+" <> @sha
  end

  defp service_name(application) do
    case application do
      :omg_child_chain_rpc -> "child_chain"
      :omg_watcher_rpc -> "watcher"
    end
  end
end
