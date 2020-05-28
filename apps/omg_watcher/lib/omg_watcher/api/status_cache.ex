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

  alias OMG.Watcher.API.StatusCache.External
  alias OMG.Watcher.API.StatusCache.Storage
  alias OMG.Watcher.SyncSupervisor

  use GenServer
  require Logger

  @type status() :: External.t()

  defstruct [:ets, :integration_module]

  @type t :: %__MODULE__{
          ets: atom(),
          integration_module: module()
        }
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
    integration_module = Keyword.get(opts, :integration_module, External)
    :ok = event_bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)
    {:ok, eth_block_number} = integration_module.get_ethereum_height()
    Storage.update_status(ets, key(), eth_block_number, integration_module)
    _ = Logger.info("Started #{inspect(__MODULE__)}.")
    {:ok, %__MODULE__{ets: ets, integration_module: integration_module}}
  end

  @doc """
  This gets periodically called (defined by Ethereum height change).
  """

  def handle_info({:internal_event_bus, :ethereum_new_height, eth_block_number}, state) do
    _ = Storage.update_status(state.ets, key(), eth_block_number, state.integration_module)
    {:noreply, state}
  end

  defp key() do
    :status
  end
end
