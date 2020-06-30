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

  alias Itest.{Account, Poller}

  require Logger

  @node1 "geth-1"
  @node2 "geth-2"
  @pause_seconds 100

  @rpc_nodes ["http://localhost:9000", "http://localhost:9001"]

  def execute_in_reorg(func) do
    if Application.get_env(:cabbage, :reorg) do
      pause_container!(@node1)
      unpause_container!(@node2)

      response = func.()

      Process.sleep(@pause_seconds * 1000)

      pause_container!(@node2)
      unpause_container!(@node1)

      response = func.()

      # the second sleep is shorter so the number of generated blocks is smaller
      Process.sleep(floor(@pause_seconds / 4) * 1000)

      unpause_container!(@node2)
      unpause_container!(@node1)

      # let the nodes connect to each other
      # Process.sleep(60 * 1000)

      response
    else
      func.()
    end
  end

  def fetch_balance(address) do
    address
    |> Poller.account_get_balances()
    |> IO.inspect()

    fetch_balance(address)
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

  defp pause_container!(container) do
    pause_container_url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/containers/#{container}/pause"

    pause_response = post_request!(pause_container_url)

    Logger.info("Chain reorg: pause response - #{inspect(pause_response)}")

    204 = pause_response.status_code
  end

  defp unpause_container!(container) do
    unpause_container_url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/containers/#{container}/unpause"

    unpause_response = post_request!(unpause_container_url)

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
