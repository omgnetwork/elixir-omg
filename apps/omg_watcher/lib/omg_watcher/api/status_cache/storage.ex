# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.API.StatusCache.Storage do
  @moduledoc """
  Watcher status API storage
  """

  @doc """
  This gets periodically called (defined by Ethereum height change).
  """
  def update_status(ets, key, eth_block_number, integration_module) do
    {:ok, status} = integration_module.get_status(eth_block_number)
    :ets.insert(ets, {key, status})
  end

  def ensure_ets_init(status_cache) do
    case :ets.info(status_cache) do
      :undefined ->
        ^status_cache = :ets.new(status_cache, [:set, :public, :named_table, read_concurrency: true])
        :ok

      _ ->
        :ok
    end
  end
end
