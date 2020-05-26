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

defmodule OMG.Watcher.API.StatusCache do
  @moduledoc """
  Watcher status API cache
  """

  alias OMG.Eth.EthereumHeight
  alias OMG.Watcher.API.StatusCache.Storage
  alias OMG.Watcher.SyncSupervisor

  use GenServer

  @type t() :: atom()
  @type status() :: Storage.t()

  @spec get() :: status()
  def get() do
    :ets.lookup_element(SyncSupervisor.status_cache(), key(), 2)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec init(Keyword.t()) :: {:ok, t()}
  def init(opts) do
    event_bus = Keyword.fetch!(opts, :event_bus)
    ets = Keyword.fetch!(opts, :ets)
    :ok = event_bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)
    state = ets
    {:ok, eth_block_number} = EthereumHeight.get()
    Storage.update_status(state, key(), eth_block_number)
    {:ok, state}
  end

  @doc """
  This gets periodically called (defined by Ethereum height change).
  """

  def handle_info({:internal_event_bus, :ethereum_new_height, eth_block_number}, state) do
    Storage.update_status(state, key(), eth_block_number)
    {:noreply, state}
  end

  defp key() do
    :status
  end
end
