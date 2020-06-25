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
  use GenServer

  require Logger

  @node1 "geth-1"
  @node2 "geth-2"
  @pause_seconds 100

  def finish_reorg() do
    if Application.get_env(:cabbage, :reorg) do
      unpause_container!(@node1)
      unpause_container!(@node2)

      Process.sleep(@pause_seconds * 1000)
    end
  end

  def start_reorg() do
    if Application.get_env(:cabbage, :reorg) do
      GenServer.cast(__MODULE__, :reorg_step1)
    end
  end

  def execute_in_reorg(func) do
    if Application.get_env(:cabbage, :reorg) do
      pause_container!(@node1)
      unpause_container!(@node2)

      Process.sleep(@pause_seconds * 1000)

      pause_container!(@node2)
      unpause_container!(@node1)

      response = func.()

      Process.sleep(@pause_seconds / 2 * 1000)

      unpause_container!(@node2)
      unpause_container!(@node1)

      Process.sleep(@pause_seconds * 1000)

      response
    else
      func.()
    end
  end

  def start_link() do
    print_available_containers()

    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast(:reorg_step1, %{reorg: true} = state) do
    Logger.error("Chain reorg: can not trigger the reorg, it's already in reorg")

    {:noreply, state}
  end

  @impl true
  def handle_cast(:reorg_step1, _) do
    Logger.info("Chain reorg: pausing the first node")

    pause_container!(@node1)

    Process.send_after(self(), :reorg_step2, @pause_seconds * 1000)

    {:noreply, %{reorg: true}}
  end

  @impl true
  def handle_info(:reorg_step2, %{reorg: false} = state) do
    Logger.error("Chain reorg: can not start the second step of reorg")

    {:noreply, state}
  end

  @impl true
  def handle_info(:reorg_step2, %{reorg: true} = state) do
    Logger.info("Chain reorg: unpausing the first node, pausing the second node")

    pause_container!(@node2)
    unpause_container!(@node1)

    Process.send_after(self(), :finish_reorg, @pause_seconds * 1000)

    {:noreply, state}
  end

  @impl true
  def handle_info(:finish_reorg, _state) do
    Logger.info("Chain reorg: reorg finished, unpausing both nodes")

    unpause_container!(@node1)
    unpause_container!(@node2)

    {:noreply, %{reorg: false}}
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

  defp post_request!(url) do
    HTTPoison.post!(url, "", [{"content-type", "application/json"}],
      timeout: 60_000,
      recv_timeout: 60_000
    )
  end

  defp print_available_containers() do
    url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/containers/json"

    response =
      HTTPoison.get!(url, [{"content-type", "application/json"}],
        timeout: 60_000,
        recv_timeout: 60_000
      )

    Logger.info("Chain reorg: running containers - #{inspect(Jason.decode!(response.body), limit: :infinity)}")
  end
end
