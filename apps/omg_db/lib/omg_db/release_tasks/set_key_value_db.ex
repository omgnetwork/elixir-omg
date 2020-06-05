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
  @behaviour Config.Provider
  require Logger
  @app :omg_db
  @default_db_folder "app"

  def init(args) do
    args
  end

  def load(config, args) do
    _ = on_load()
    release = Keyword.get(args, :release)

    case get_env("DB_PATH") do
      root_path when is_binary(root_path) ->
        set_db(config, root_path, release)

      _ ->
        root_path = Path.join([System.user_home!(), ".omg/data"])
        set_db(config, root_path, release)
    end
  end

  defp set_db(config, root_path, release) do
    path = Path.join([root_path, "#{release}", @default_db_folder])
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: DB_PATH Value: #{inspect(path)}.")
    # if we want to access the updated path in the same VM instance, we need to update it imidiatelly
    Application.put_env(@app, :path, path)
    Config.Reader.merge(config, omg_db: [path: path])
  end

  defp get_env(key), do: System.get_env(key)

  defp on_load() do
    _ = Application.ensure_all_started(:logger)
    _ = Application.load(@app)
  end
end
