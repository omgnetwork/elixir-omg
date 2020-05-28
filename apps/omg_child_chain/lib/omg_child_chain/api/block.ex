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

defmodule OMG.ChildChain.API.Block do
  @moduledoc """
  Child Chain API for blocks.
  """

  alias OMG.ChildChain.API.BlocksCache
  alias OMG.Block

  @spec get_block(binary()) :: {:ok, Block.t()} | {:error, :not_found}
  def get_block(hash) do
    case BlocksCache.get(hash) do
      :not_found -> {:error, :not_found}
      block -> {:ok, block}
    end
  end
end
