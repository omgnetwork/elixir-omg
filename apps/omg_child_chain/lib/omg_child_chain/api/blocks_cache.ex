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

defmodule OMG.ChildChain.API.BlocksCache do
  @moduledoc """
  Allows for quick access to a fresh subset of blocks by keeping them in ETS, independent of `OMG.DB`.
  """

  alias OMG.ChildChain.API.BlocksCache.Storage
  alias OMG.ChildChain.Supervisor

  require Logger

  @type t :: %__MODULE__{ets: atom(), cache_miss_counter: pos_integer()}
  defstruct [:ets, cache_miss_counter: 0]

  # this is executed in the request process so while the ETS is getting populated
  # we hit the genserver
  def get(block_hash) do
    case :ets.lookup(Supervisor.blocks_cache(), block_hash) do
      [] -> GenServer.call(__MODULE__, {:get, block_hash}, 60_000)
      [{^block_hash, block}] -> block
    end
  end

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  ##### Server
  use GenServer

  def init(init_arg) do
    ets = Keyword.fetch!(init_arg, :ets)
    _ = Logger.info("Starting #{__MODULE__}")
    {:ok, %__MODULE__{ets: ets}}
  end

  def handle_call({:get, block_hash}, _from, state) do
    result = Storage.get(block_hash, state.ets)
    cache_miss_counter = state.cache_miss_counter + 1
    _ = Logger.info("Cache miss for #{inspect(block_hash)}, counter #{cache_miss_counter}.")
    {:reply, result, %{state | cache_miss_counter: cache_miss_counter}}
  end
end
