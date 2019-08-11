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

defmodule OMG.DB.ReleaseTasks.SetKeyValueDB do
  @moduledoc false
  use Distillery.Releases.Config.Provider
  require Logger
  @app :omg_db

  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)
    type = validate_db_type(get_env("DB_TYPE"))
    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: DB_TYPE Value: #{inspect(type)}.")
    :ok = Application.put_env(:omg_db, :type, type, persistent: true)

    path =
      case get_env("DB_PATH") do
        path when is_binary(path) ->
          :ok = Application.put_env(:omg_db, :path, path, persistent: true)
          path

        _ ->
          path = Path.join([System.user_home!(), ".omg/data"])
          :ok = Application.put_env(:omg_db, :path, path, persistent: true)
          path
      end

    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: DB_PATH Value: #{inspect(path)}.")
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_db_type(value) when is_binary(value), do: to_db_type(String.upcase(value))
  defp validate_db_type(_), do: Application.get_env(@app, :type)

  defp to_db_type("LEVELDB"), do: :leveldb
  defp to_db_type("ROCKSDB"), do: :rocksdb
  defp to_db_type(_), do: exit("DB type not found. Choose from LevelDB or RocksDB.")
end
