# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.API.EthereumEventListener do
  @moduledoc """
  Periodically fetches events made on dynamically changing block range
  on parent chain and feeds them to state.
  For code simplicity it listens for events in blocks with a configured finality margin.
  """

  alias OMG.API.EthereumEventListener.Core
  alias OMG.Eth
  use OMG.API.LoggerExt

  ### Client

  def start_link(config, get_events_callback, process_events_callback) do
    GenServer.start_link(__MODULE__, {config, get_events_callback, process_events_callback})
  end

  ### Server

  use GenServer

  def init(
        {%{
           block_finality_margin: finality_margin,
           max_blocks_in_fetch: max_blocks,
           get_events_interval: get_events_interval
         }, get_ethereum_events_callback, process_events_callback}
      ) do
    # FIXME: initialize state with the last ethereum block we have seen events from

    {:ok, parent_start} = Eth.get_root_deployment_height()
    schedule_get_events(0)

    _ = Logger.info(fn -> "Starting EthereumEventListener" end)

    {:ok,
     %Core{
       last_event_block: parent_start,
       block_finality_margin: finality_margin,
       max_blocks_in_fetch: max_blocks,
       get_events_interval: get_events_interval,
       get_ethereum_events_callback: get_ethereum_events_callback,
       process_events_callback: process_events_callback
     }}
  end

  def handle_info(:get_events, state) do
    {:ok, eth_block_height} = Eth.get_ethereum_height()

    with {:ok, new_state, next_get_events_interval, eth_block_from, eth_block_to} <-
           Core.get_events_block_range(state, eth_block_height) do
      {:ok, events} = state.get_ethereum_events_callback.(eth_block_from, eth_block_to)
      :ok = state.process_events_callback.(events)

      _ =
        Logger.debug(fn ->
          "get_events called successfully with '#{inspect(Enum.count(events))}' events processed."
        end)

      schedule_get_events(next_get_events_interval)
      {:noreply, new_state}
    else
      {:no_blocks_with_event, state, next_get_events_interval} ->
        _ = Logger.debug(fn -> "get_events - no blocks with event" end)
        schedule_get_events(next_get_events_interval)
        {:noreply, state}
    end
  end

  defp schedule_get_events(interval) do
    Process.send_after(self(), :get_events, interval)
  end
end
