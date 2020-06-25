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

defmodule OMG.WatcherInfo.ExitConsumer do
  @moduledoc """
  Subscribes to exit events and inserts them to WatcherInfo.DB.
  """
  require Logger
  alias OMG.WatcherInfo.DB.EthEvent

  @default_bus_module OMG.Bus

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  ### Server

  use GenServer

  def init(args) do
    bus_module = Keyword.get(args, :bus_module, @default_bus_module)

    state = %{
      topics: Keyword.fetch!(args, :topics),
      event_type: Keyword.fetch!(args, :event_type),
      exits: []
    }

    :ok = bus_module.subscribe(state.topic, link: true)

    _ = Logger.info("Started #{inspect(__MODULE__)}, listen to #{inspect(state.topic)}")
    {:ok, state}
  end

  def handle_info({:internal_event_bus, :data, %{blknum: block_number, eth_height: eth_height}}, state) do
    # data = Enum.find all blocks up to eth_height (inclusive) from state.exits
    # Enum.each(data, fn -> 
    # #_ = EthEvent.insert_exits!(data, state.event_type)
    # end)

    {:noreply, %{state | exits: Kernel.--(state.exits, data)}}
  end

  def handle_info({:internal_event_bus, :data, data}, state) do
    _ =
      Logger.debug(
        "Received event from #{inspect(state.topic)} typeof #{inspect(state.event_type)} Data:\n#{inspect(data)}"
      )

    # _ = EthEvent.insert_exits!(data, state.event_type)
    {:noreply, %{state | exits: Kernel.++(state.exits, data)}}
  end
end
