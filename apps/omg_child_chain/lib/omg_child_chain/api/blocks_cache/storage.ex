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

defmodule OMG.ChildChain.API.BlocksCache.Storage do
  @moduledoc """
  Logic of the service to serve freshest blocks quickly.
  """
  alias OMG.Block
  alias OMG.DB

  @doc """
  The idea behind having another lookup in ETS is that once a 
  fresh block is published every watcher is racing to get that block.
  The first read in BlocksCache would be a miss, and the request message would go sit in the
  gen server queue. But the first Watcher that requested the block would insert the block in
  ETS. We're trying to protect RocksDB single server.
  """
  @spec get(binary(), atom()) :: :not_found | {:ets, Block.t()} | {:db, Block.t()}
  def get(block_hash, ets) do
    case lookup(ets, block_hash) do
      [] ->
        case DB.blocks([block_hash]) do
          {:ok, [:not_found]} ->
            :not_found

          {:ok, [db_block]} ->
            block = db_block |> Block.from_db_value() |> Block.to_api_format()
            true = :ets.insert(ets, {block_hash, block})
            {:db, block}
        end

      [{^block_hash, block}] ->
        {:ets, block}
    end
  end

  def ensure_ets_init(blocks_cache) do
    case :ets.info(blocks_cache) do
      :undefined ->
        ^blocks_cache = :ets.new(blocks_cache, [:set, :public, :named_table, read_concurrency: true])
        :ok

      _ ->
        :ok
    end
  end

  def lookup(ets, block_hash) do
    :ets.lookup(ets, block_hash)
  end
end
