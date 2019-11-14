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

    path =
      case get_env("DB_PATH") do
        root_path when is_binary(root_path) ->
          {:ok, path} = set_db(root_path)
          path

        _ ->
          root_path = Path.join([System.user_home!(), ".omg/data"])
          {:ok, path} = set_db(root_path)
          path
      end

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: DB_PATH Value: #{inspect(path)}.")
    :ok
  end

  defp set_db(root_path) do
    app =
      case Code.ensure_loaded?(OMG.Watcher) do
        true -> :watcher
        _ -> :child_chain
      end

    path = Path.join([root_path, "#{app}"])
    :ok = Application.put_env(:omg_db, :path, path, persistent: true)
    {:ok, path}
  end

  defp get_env(key), do: System.get_env(key)
end
