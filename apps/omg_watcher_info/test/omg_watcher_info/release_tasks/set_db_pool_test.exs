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

defmodule OMG.WatcherInfo.ReleaseTasks.SetDbPoolTest do
  use ExUnit.Case, async: true
  alias OMG.WatcherInfo.ReleaseTasks.SetDbPool

  @app :omg_watcher_info
  @config_key OMG.WatcherInfo.DB.Repo

  describe "WATCHER_INFO_DB_POOL_SIZE" do
    test "sets the repo's pool_size to WATCHER_INFO_DB_POOL_SIZE" do
      assert load_and_fetch("WATCHER_INFO_DB_POOL_SIZE", "123", :pool_size) == 123
      :ok = System.delete_env("WATCHER_INFO_DB_POOL_SIZE")
    end

    test "uses the default pool_size value if WATCHER_INFO_DB_POOL_SIZE is not defined" do
      default_value = Application.get_env(@app, :pool_size)
      assert load_and_fetch("WATCHER_INFO_DB_POOL_SIZE", nil, :pool_size) == default_value
      :ok = System.delete_env("WATCHER_INFO_DB_POOL_SIZE")
    end

    test "fails if WATCHER_INFO_DB_POOL_SIZE is not a valid stringified integer" do
      assert catch_error(load_and_fetch("WATCHER_INFO_DB_POOL_SIZE", "not integer", :pool_size)) == :badarg
      :ok = System.delete_env("WATCHER_INFO_DB_POOL_SIZE")
    end
  end

  describe "WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS" do
    test "sets the repo's queue_target to WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS" do
      assert load_and_fetch("WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS", "123", :queue_target) == 123
      :ok = System.delete_env("WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS")
    end

    test "uses the default queue_target value if WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS is not defined" do
      default_value = Application.get_env(@app, :queue_target)
      assert load_and_fetch("WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS", nil, :queue_target) == default_value
      :ok = System.delete_env("WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS")
    end

    test "fails if WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS is not a valid stringified integer" do
      assert catch_error(load_and_fetch("WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS", "not integer", :queue_target)) == :badarg
      :ok = System.delete_env("WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS")
    end
  end

  describe "WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS" do
    test "sets the repo's queue_interval to WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS" do
      assert load_and_fetch("WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS", "123", :queue_interval) == 123
      :ok = System.delete_env("WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS")
    end

    test "uses the default queue_interval value if WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS is not defined" do
      default_value = Application.get_env(@app, :queue_interval)
      assert load_and_fetch("WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS", nil, :queue_interval) == default_value
      :ok = System.delete_env("WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS")
    end

    test "fails if WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS is not a valid stringified integer" do
      assert catch_error(load_and_fetch("WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS", "not integer", :queue_interval)) == :badarg
      :ok = System.delete_env("WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS")
    end
  end

  defp load_and_fetch(env_name, nil, config_name) do
    :ok = System.delete_env(env_name)
    config = SetDbPool.load([], [])

    fetch(config, config_name)
  end

  defp load_and_fetch(env_name, env_value, config_name) do
    :ok = System.put_env(env_name, env_value)
    config = SetDbPool.load([], [])

    fetch(config, config_name)
  end

  defp fetch(config, config_name) do
    config |> Keyword.fetch!(@app) |> Keyword.fetch!(@config_key) |> Keyword.fetch!(config_name)
  end
end
