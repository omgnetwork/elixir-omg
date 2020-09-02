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
  @behaviour Config.Provider
  require Logger

  @init_heights_config [last_ife_exit_deleted_eth_height: 0]

  def init(args) do
    args
  end

  def load(config, db_module: db_module) do
    _ = on_load()

    :ok =
      Enum.each(
        @init_heights_config,
        fn {key, init_val} ->
          case db_module.get_single_value(key) do
            :not_found ->
              :ok = db_module.multi_update([{:put, key, init_val}])
              _ = Logger.info("#{key} not set. Setting it to #{init_val}")
              :ok

            {:ok, _} ->
              :ok
          end
        end
      )

    config
  end

  defp on_load() do
    {:ok, _} = Application.ensure_all_started(:logger)
    {:ok, _} = Application.ensure_all_started(:omg_db)
  end
end
