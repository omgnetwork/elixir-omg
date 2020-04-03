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

defmodule OMG.WatcherRPC.ReleaseTasks.SetEndpointTest do
  use ExUnit.Case, async: false
  alias OMG.WatcherRPC.ReleaseTasks.SetEndpoint
  alias OMG.WatcherRPC.Web.Endpoint

  @app :omg_watcher_rpc

  test "if environment variables get applied in the configuration" do
    :ok = System.put_env("PORT", "1")
    :ok = System.put_env("HOSTNAME", "host")
    config = SetEndpoint.load([], [])
    port = config |> Keyword.fetch!(@app) |> Keyword.fetch!(Endpoint) |> Keyword.fetch!(:http) |> Keyword.fetch!(:port)
    host = config |> Keyword.fetch!(@app) |> Keyword.fetch!(Endpoint) |> Keyword.fetch!(:http) |> Keyword.fetch!(:host)
    assert port == 1
    assert host == "host"
  end

  test "if default configuration is used when there's no environment variables" do
    :ok = System.delete_env("PORT")
    :ok = System.delete_env("HOSTNAME")
    config = SetEndpoint.load([], [])
    port = config |> Keyword.fetch!(@app) |> Keyword.fetch!(Endpoint) |> Keyword.fetch!(:http) |> Keyword.fetch!(:port)
    host = config |> Keyword.fetch!(@app) |> Keyword.fetch!(Endpoint) |> Keyword.fetch!(:http) |> Keyword.fetch!(:host)
    config_port = Application.get_env(@app, Endpoint)[:port]
    config_host = Application.get_env(@app, Endpoint)[:host]
    assert port == config_port
    assert host == config_host
  end
end
