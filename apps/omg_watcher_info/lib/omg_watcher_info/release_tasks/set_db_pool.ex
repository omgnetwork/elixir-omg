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

defmodule OMG.WatcherInfo.ReleaseTasks.SetDbPool do
  @moduledoc false
  @behaviour Config.Provider
  require Logger

  @app :omg_watcher_info
  @config_key OMG.WatcherInfo.DB.Repo

  # Note that we're setting these configs directly into Ecto.Repo's implementation,
  # so the config naming deviates with the env var names in order to align with Ecto.Repo.
  # See: https://hexdocs.pm/db_connection/DBConnection.html#start_link/2-queue-config
  @mapping [
    # {env_var, config_name}
    {"WATCHER_INFO_DB_POOL_SIZE", :pool_size},
    {"WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS", :queue_target},
    {"WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS", :queue_interval}
  ]

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = on_load()
    configs = [{@config_key, load_repo_configs(@app, @mapping)}]

    Config.Reader.merge(config, [{@app, configs}])
  end

  # Returns:
  #   [
  #     pool_size: 10,
  #     queue_target: 50,
  #     queue_interval: 1000
  #   ]
  defp load_repo_configs(app, mapping) do
    Enum.map(mapping, fn {env_var, config_name} ->
      default = Application.get_env(app, config_name)
      value = env_var |> System.get_env() |> validate_integer(default)
      _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{config_name} Value: #{inspect(value)}.")

      {config_name, value}
    end)
  end

  defp validate_integer(nil, default), do: default
  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)

  defp on_load() do
    _ = Application.ensure_all_started(:logger)
    _ = Application.load(@app)
  end
end
