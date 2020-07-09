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

defmodule Itest.Reorg do
  @moduledoc """
    Chain reorg triggering logic.
  """

  alias Itest.Client

  require Logger

  @node1 "geth-1"
  @node2 "geth-2"

  @rpc_nodes ["http://localhost:9000", "http://localhost:9001"]

  def execute_in_reorg(func) do
    if Application.get_env(:cabbage, :reorg) do
      wait_for_nodes_to_be_in_sync()

      {:ok, block_before_reorg} = Client.get_latest_block_number()

      pause_container!(@node1)
      unpause_container!(@node2)

      :ok = Client.wait_until_block_number(block_before_reorg + 4)

      func.()

      {:ok, block_on_the_first_node1} = Client.get_latest_block_number()

      :ok = Client.wait_until_block_number(block_on_the_first_node1 + 2)

      {:ok, block_on_the_first_node2} = Client.get_latest_block_number()

      pause_container!(@node2)
      unpause_container!(@node1)

      :ok = Client.wait_until_block_number(block_before_reorg + 4)

      response = func.()

      :ok = Client.wait_until_block_number(block_on_the_first_node2 + 2)

      unpause_container!(@node2)
      unpause_container!(@node1)

      wait_for_nodes_to_be_in_sync()

      response
    else
      func.()
    end
  end

  def create_account_from_secret(secret, passphrase) do
    result =
      Enum.map(@rpc_nodes, fn rpc_node ->
        with_retries(fn ->
          Ethereumex.HttpClient.request("personal_importRawKey", [secret, passphrase], url: rpc_node)
        end)
      end)

    List.first(result)
  end

  def unlock_account(addr, passphrase) do
    Enum.each(@rpc_nodes, fn rpc_node ->
      {:ok, true} =
        with_retries(fn ->
          Ethereumex.HttpClient.request("personal_unlockAccount", [addr, passphrase, 0], url: rpc_node)
        end)
    end)
  end

  def wait_until_peer_count(peer_count) do
    _ = Logger.info("Waiting for peer count to equal to #{peer_count}")

    Enum.each(@rpc_nodes, fn node -> do_wait_until_peer_count(node, peer_count) end)
  end

  defp wait_for_nodes_to_be_in_sync() do
    wait_until_peer_count(1) && Enum.each(@rpc_nodes, fn rpc_node -> wait_until_synced(rpc_node) end) &&
      wait_until_peer_count(1)
  end

  defp wait_until_synced(node) do
    case Ethereumex.HttpClient.request("eth_syncing", [], url: node) do
      {:ok, false} ->
        :ok

      _other ->
        Process.sleep(1_000)
        wait_until_synced(node)
    end
  end

  defp do_wait_until_peer_count(node, peer_count) do
    case Ethereumex.HttpClient.request("net_peerCount", [], url: node) do
      {:ok, "0x" <> number_hex} ->
        {count, ""} = Integer.parse(number_hex, 16)

        if count >= peer_count do
          :ok
        else
          Process.sleep(1_000)
          do_wait_until_peer_count(node, peer_count)
        end

      _other ->
        Process.sleep(1_000)
        do_wait_until_peer_count(node, peer_count)
    end
  end

  defp pause_container!(container) do
    pause_container_url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/containers/#{container}/pause"

    pause_response = post_request!(pause_container_url)

    Logger.info("Chain reorg: pause response - #{inspect(pause_response)}")

    # the pause operation is not instant, let's wait for 2s
    Process.sleep(2_000)

    204 = pause_response.status_code
  end

  defp unpause_container!(container) do
    unpause_container_url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/containers/#{container}/unpause"

    unpause_response = post_request!(unpause_container_url)

    # the unpause operation is not instant, let's wait for 2s
    Process.sleep(2_000)

    Logger.info("Chain reorg: unpause response - #{inspect(unpause_response)}")
  end

  defp with_retries(func, total_time \\ 510, current_time \\ 0) do
    case func.() do
      {:ok, _} = result ->
        result

      result ->
        if current_time < total_time do
          Process.sleep(1_000)
          with_retries(func, total_time, current_time + 1)
        else
          result
        end
    end
  end

  defp post_request!(url) do
    HTTPoison.post!(url, "", [{"content-type", "application/json"}],
      timeout: 60_000,
      recv_timeout: 60_000
    )
  end
end
