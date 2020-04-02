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

defmodule OMG.WatcherInfo.ReleaseTasks.SetDB do
  @moduledoc false
  @behaviour Config.Provider
  require Logger
  @app :omg_watcher_info

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = on_load()

    db_config =
      @app
      |> Application.get_env(OMG.WatcherInfo.DB.Repo)
      |> Keyword.put(:url, get_db_url())

    Config.Reader.merge(config, omg_watcher_info: [{OMG.WatcherInfo.DB.Repo, db_config}])
  end

  defp get_db_url() do
    db_url = validate_string(get_env("DATABASE_URL"), Application.get_env(@app, OMG.WatcherInfo.DB.Repo)[:url])

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: DATABASE_URL Value: #{inspect(db_url)}.")
    db_url
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_string(value, _default) when is_binary(value), do: value
  defp validate_string(_, default), do: default

  defp on_load() do
    _ = Application.ensure_all_started(:logger)
    _ = Application.load(@app)
  end
end
