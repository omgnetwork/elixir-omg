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

  alias OMG.WatcherInfo.DB

  @doc """
  Retrieves a specific block by hash
  """
  @spec get(binary()) :: {:ok, %DB.Block{}} | {:error, :block_not_found}
  def get(block_id) do
    case DB.Block.get_by_hash(block_id) do
      nil -> {:error, :block_not_found}
      block -> {:ok, block}
    end
  end
end
