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

defmodule OMG.ChildChainRPC.ReleaseTasks.SetEndpointTest do
  use ExUnit.Case, async: false
  alias OMG.ChildChainRPC.ReleaseTasks.SetEndpoint
  alias OMG.ChildChainRPC.Web.Endpoint

  @app :omg_child_chain_rpc
  @test_host "cc.test.example.com"
  @test_port "9999999999999999"
  @test_port_int String.to_integer(@test_port)
  @configuration_old Application.get_env(@app, Endpoint)

  setup do
    on_exit(fn -> :ok = Application.put_env(@app, Endpoint, @configuration_old, persistent: true) end)
  end

  test "if environment variables get applied in the configuration" do
    :ok = System.put_env("PORT", @test_port)
    :ok = System.put_env("HOSTNAME", @test_host)
    :ok = SetEndpoint.load([], [])
    configuration = Enum.sort(deep_sort(Application.get_env(@app, Endpoint)))
    http_updated = configuration[:http]
    url_updated = configuration[:url]
    [host: @test_host, port: 80] = Enum.sort(url_updated)
    [port: @test_port_int] = Enum.sort(http_updated)

    ^configuration =
      @configuration_old
      |> Keyword.put(:http, port: @test_port_int)
      |> Keyword.put(:url, host: @test_host, port: 80)
      |> deep_sort()
      |> Enum.sort()
  end

  test "if default configuration is used when there's no environment variables" do
    :ok = System.delete_env("PORT")
    :ok = System.delete_env("HOSTNAME")
    :ok = SetEndpoint.load([], [])
    configuration = Application.get_env(@app, Endpoint)

    sorted_configuration = Enum.sort(deep_sort(configuration))
    ^sorted_configuration = Enum.sort(deep_sort(@configuration_old))
  end

  defp deep_sort(values) do
    Enum.map(values, fn {key, value} ->
      if is_list(value) do
        {key, Enum.sort(value)}
      else
        {key, value}
      end
    end)
  end
end
