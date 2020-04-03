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
  use ExUnit.Case, async: true
  alias OMG.Eth.ReleaseTasks.SetEthereumClient

  @app :omg_eth

  test "if defaults are used when env vars are not set" do
    default_url = Application.get_env(:ethereumex, :url)
    default_eth_node = Application.get_env(@app, :eth_node)
    config = SetEthereumClient.load([], [])
    eth_node = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:eth_node)
    url = config |> Keyword.fetch!(:ethereumex) |> Keyword.fetch!(:url)
    assert url == default_url
    assert eth_node == default_eth_node
  end

  test "if values are used when env vars set" do
    :ok = System.put_env("ETHEREUM_RPC_URL", "url")
    :ok = System.put_env("ETH_NODE", "geth")
    config = SetEthereumClient.load([], [])
    eth_node = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:eth_node)
    url = config |> Keyword.fetch!(:ethereumex) |> Keyword.fetch!(:url)
    assert url == "url"
    assert eth_node == :geth

    :ok = System.put_env("ETH_NODE", "parity")
    config = SetEthereumClient.load([], [])
    eth_node = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:eth_node)
    url = config |> Keyword.fetch!(:ethereumex) |> Keyword.fetch!(:url)
    assert url == "url"
    assert eth_node == :parity

    :ok = System.put_env("ETH_NODE", "infura")
    config = SetEthereumClient.load([], [])
    eth_node = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:eth_node)
    url = config |> Keyword.fetch!(:ethereumex) |> Keyword.fetch!(:url)
    assert url == "url"
    assert eth_node == :infura
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
