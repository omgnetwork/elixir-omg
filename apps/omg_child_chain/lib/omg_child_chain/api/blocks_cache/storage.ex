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

defmodule OMG.ChildChain.BlocksCache.Storage do
  @moduledoc """
  Logic of the service to serve freshest blocks quickly.
  """
  alias OMG.Block
  alias OMG.DB

  @spec get(binary(), atom()) :: :not_found | Block.t()
  def get(block_hash, ets) do
    case DB.blocks([block_hash]) do
      {:ok, [:not_found]} ->
        :not_found

      {:ok, [db_block]} ->
        block = db_block |> Block.from_db_value() |> Block.to_api_format()
        :ets.insert(ets, {block_hash, block})
        block
    end
  end
end
