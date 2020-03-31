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

defmodule OMG.ReleaseTasks.SetEthereumEventsCheckIntervalTest do
  use ExUnit.Case, async: false
  alias OMG.ReleaseTasks.SetEthereumEventsCheckInterval

  @app :omg
  @env_key "ETHEREUM_EVENTS_CHECK_INTERVAL_MS"
  @config_key :ethereum_events_check_interval_ms

  setup do
    original_config = Application.get_all_env(@app)

    on_exit(fn ->
      # configuration is global state so we reset it to known values in case it got fiddled before
      :ok = Enum.each(original_config, fn {key, value} -> Application.put_env(@app, key, value, persistent: true) end)
    end)

    {:ok, %{original_config: original_config}}
  end

  test "that interval is set when the env var is present" do
    :ok = System.put_env(@env_key, "1234")
    :ok = SetEthereumEventsCheckInterval.load([],[])
    assert Application.get_env(@app, @config_key) == 1234
    :ok = System.delete_env(@env_key)
  end

  test "that no other configurations got affected", context do
    :ok = System.put_env(@env_key, "1234")
    :ok = SetEthereumEventsCheckInterval.load([],[])
    new_configs = @app |> Application.get_all_env() |> Keyword.delete(@config_key) |> Enum.sort()
    old_configs = context.original_config |> Keyword.delete(@config_key) |> Enum.sort()

    assert new_configs == old_configs
  end

  test "that the default config is used when the env var is not set" do
    old_config = Application.get_env(@app, @config_key)
    :ok = System.delete_env(@env_key)
    :ok = SetEthereumEventsCheckInterval.load([],[])
    new_config = Application.get_env(@app, @config_key)

    assert new_config == old_config
  end
end
