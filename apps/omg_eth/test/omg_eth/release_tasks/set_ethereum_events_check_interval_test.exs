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

defmodule OMG.Eth.ReleaseTasks.SetEthereumEventsCheckIntervalTest do
  use ExUnit.Case, async: true
  alias OMG.Eth.ReleaseTasks.SetEthereumEventsCheckInterval

  @app :omg_eth
  @env_key "ETHEREUM_EVENTS_CHECK_INTERVAL_MS"
  @config_key :ethereum_events_check_interval_ms

  test "that interval is set when the env var is present" do
    :ok = System.put_env(@env_key, "1234")
    config = SetEthereumEventsCheckInterval.load([], [])
    ethereum_events_check_interval_ms = config |> Keyword.fetch!(@app) |> Keyword.fetch!(@config_key)
    assert ethereum_events_check_interval_ms == 1234
    :ok = System.delete_env(@env_key)
  end

  test "that the default config is used when the env var is not set" do
    old_config = Application.get_env(@app, @config_key)
    :ok = System.delete_env(@env_key)
    config = SetEthereumEventsCheckInterval.load([], [])
    ethereum_events_check_interval_ms = config |> Keyword.fetch!(@app) |> Keyword.fetch!(@config_key)
    assert ethereum_events_check_interval_ms == old_config
  end
end
