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

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ### Server

  use GenServer

  def init(:ok) do
    :ok = OMG.Bus.subscribe({:root_chain, "ExitStarted"}, link: true)

    _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:ok, %{}}
  end

  def handle_info({:internal_event_bus, :data, data}, state) do
    _ = EthEvent.insert_exits!(data)
    {:noreply, state}
  end
end
