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

defmodule OMG.Eth.ReleaseTasks.SetEthereumClientTest do
  use ExUnit.Case, async: false
  alias OMG.Eth.ReleaseTasks.SetEthereumClient

  @app :omg_eth
  @configuration_old Application.get_all_env(@app)
  @configuration_old_ethereumex Application.get_all_env(:ethereumex)

  setup %{} do
    on_exit(fn ->
      :ok =
        Enum.each(@configuration_old, fn {key, value} -> Application.put_env(@app, key, value, persistent: true) end)

      :ok =
        Enum.each(@configuration_old_ethereumex, fn {key, value} ->
          Application.put_env(:ethereumex, key, value, persistent: true)
        end)

      Enum.each([:sasl, :os_mon, :omg_status], &Application.stop/1)
    end)

    :ok
  end

  test "if defaults are used when env vars are not set" do
    url = Application.get_env(:ethereumex, :url)
    eth_node = Application.get_env(@app, :eth_node)
    :ok = SetEthereumClient.load([], [])

    assert Application.get_env(:ethereumex, :url) == url
    assert Application.get_env(@app, :eth_node) == eth_node
  end

  test "if values are used when env vars set" do
    :ok = System.put_env("ETHEREUM_RPC_URL", "url")
    :ok = System.put_env("ETH_NODE", "geth")
    :ok = SetEthereumClient.load([], [])
    "url" = Application.get_env(:ethereumex, :url)
    :geth = Application.get_env(@app, :eth_node)

    :ok = System.put_env("ETH_NODE", "parity")
    :ok = SetEthereumClient.load([], [])
    "url" = Application.get_env(:ethereumex, :url)
    :parity = Application.get_env(@app, :eth_node)

    :ok = System.put_env("ETH_NODE", "infura")
    :ok = SetEthereumClient.load([], [])
    "url" = Application.get_env(:ethereumex, :url)
    :infura = Application.get_env(@app, :eth_node)
    # cleanup
    :ok = System.delete_env("ETHEREUM_RPC_URL")
    :ok = System.delete_env("ETH_NODE")
  end

  test "if faulty eth node exits" do
    :ok = System.put_env("ETH_NODE", "random random random")

    try do
      SetEthereumClient.load([], [])
    catch
      :exit, _reason ->
        :ok = System.delete_env("ETH_NODE")
    end
  end
end
