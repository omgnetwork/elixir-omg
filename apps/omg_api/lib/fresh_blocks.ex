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

defmodule OMG.API.FreshBlocks do
  @moduledoc """
  Allows for quick access to a fresh subset of blocks by keeping them in memory, independent of `OMG.DB`.
  """

  use OMG.API.LoggerExt

  alias OMG.API.Block
  alias OMG.API.FreshBlocks.Core
  alias OMG.DB

  ##### Client
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec get(block_hash :: binary) :: {:ok, Block.t()} | {:error, :not_found | any}
  def get(block_hash) do
    GenServer.call(__MODULE__, {:get, block_hash})
  end

  @spec push(Block.t()) :: :ok
  def push(block) do
    GenServer.cast(__MODULE__, {:push, block})
  end

  ##### Server
  use GenServer

  def init(:ok) do
    {:ok, %Core{}}
  end

  def handle_call({:get, block_hash}, _from, %Core{} = state) do
    result =
      with {fresh_block, block_hashes_to_fetch} <- Core.get(block_hash, state),
           {:ok, _} = db_result <- DB.blocks(block_hashes_to_fetch),
           do: Core.combine_getting_results(fresh_block, db_result)

    _ = Logger.debug(fn -> "get block resulted with '#{inspect(result)}', block_hash '#{inspect(block_hash)}'" end)

    {:reply, result, state}
  end

  def handle_cast({:push, %Block{transactions: [], number: block_number, hash: block_hash}}, state) do
    _ =
      Logger.debug(fn ->
        "No new empty block pushed, blknum '#{inspect(block_number)}', hash '#{inspect(block_hash)}'"
      end)

    {:noreply, state}
  end

  def handle_cast({:push, %Block{number: block_number, hash: block_hash} = block}, state) do
    {:ok, new_state} = Core.push(block, state)
    _ = Logger.debug(fn -> "new block pushed, blknum '#{inspect(block_number)}', hash '#{inspect(block_hash)}'" end)

    {:noreply, new_state}
  end
end
