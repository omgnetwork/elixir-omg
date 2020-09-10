# Copyright 2019-2019 OmiseGO Pte Ltd
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

defmodule OMG.DB.ReleaseTasks.InitKeysWithValues do
  @moduledoc """
  Sets values for keys stored in RocksDB, if they are not set.
  """
  require Logger

  @keys_to_values [last_ife_exit_deleted_eth_height: 0]

  def run() do
    {:ok, _} = Application.ensure_all_started(:logger)

    path = Application.get_env(:omg_db, :path)
    Application.put_env(:omg_db, :path, path)

    case Application.ensure_all_started(:omg_db) do
      {:ok, _} ->
        Enum.each(@keys_to_values, &set_single_value/1)

      {:error, _} ->
        _ = Logger.info("Failed to start OMG.DB, proably database is not initialized")
        :ok
    end
  end

  defp set_single_value({key, init_val}) do
    case OMG.DB.RocksDB.get_single_value(key) do
      :not_found ->
        :ok = OMG.DB.RocksDB.multi_update([{:put, key, init_val}])
        _ = Logger.info("#{key} not set. Setting it to #{init_val}")
        :ok

      {:ok, _} ->
        :ok
    end
  end
end
