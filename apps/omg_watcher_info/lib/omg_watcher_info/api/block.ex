# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherInfo.API.Block do
  @moduledoc """
  Module provides operations related to plasma blocks.
  """

  alias OMG.Utils.Paginator
  alias OMG.WatcherInfo.DB

  @default_blocks_limit 100

  @doc """
  Retrieves a specific block by block number
  """
  @spec get(pos_integer()) :: {:ok, %DB.Block{}} | {:error, :block_not_found}
  def get(blknum) do
    case DB.Block.get(blknum) do
      nil -> {:error, :block_not_found}
      block -> {:ok, block}
    end
  end

  @doc """
  Retrieves a list of blocks.
  Length of the list is limited by `limit` and `page` arguments.
  """
  @spec get_blocks(Keyword.t()) :: Paginator.t()
  def get_blocks(constraints) do
    paginator = Paginator.from_constraints(constraints, @default_blocks_limit)

    DB.Block.get_blocks(paginator)
  end
end
