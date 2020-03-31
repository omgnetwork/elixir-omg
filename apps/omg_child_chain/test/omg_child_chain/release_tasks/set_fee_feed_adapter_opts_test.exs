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

defmodule OMG.ChildChain.ReleaseTasks.SetFeeFeedAdapterOptsTest do
  use ExUnit.Case, async: false
  alias OMG.ChildChain.Fees.FeedAdapter
  alias OMG.ChildChain.ReleaseTasks.SetFeeFeedAdapterOpts

  @app :omg_child_chain
  @config_key :fee_adapter
  @env_fee_adapter "FEE_ADAPTER"
  @env_fee_feed_url "FEE_FEED_URL"
  @env_fee_change_tolerance_percent "FEE_CHANGE_TOLERANCE_PERCENT"
  @env_stored_fee_update_interval_minutes "STORED_FEE_UPDATE_INTERVAL_MINUTES"

  setup do
    original_config = Application.get_all_env(@app)

    on_exit(fn ->
      # Delete all related env vars
      :ok = System.delete_env(@env_fee_adapter)
      :ok = System.delete_env(@env_fee_feed_url)
      :ok = System.delete_env(@env_fee_change_tolerance_percent)
      :ok = System.delete_env(@env_stored_fee_update_interval_minutes)

      # configuration is global state so we reset it to known values in case it got fiddled before
      :ok = Enum.each(original_config, fn {key, value} -> Application.put_env(@app, key, value, persistent: true) end)
    end)

    {:ok, %{original_config: original_config}}
  end

  test "sets the fee adapter to FeedAdapter and configure with its related env vars" do
    :ok = System.put_env(@env_fee_adapter, "feed")
    :ok = System.put_env(@env_fee_feed_url, "http://example.com/fee-feed-url")
    :ok = System.put_env(@env_fee_change_tolerance_percent, "10")
    :ok = System.put_env(@env_stored_fee_update_interval_minutes, "60000")
    :ok = SetFeeFeedAdapterOpts.init([])

    {adapter, opts: adapter_opts} = Application.get_env(@app, @config_key)
    assert adapter == FeedAdapter
    assert adapter_opts[:fee_feed_url] == "http://example.com/fee-feed-url"
    assert adapter_opts[:fee_change_tolerance_percent] == 10
    assert adapter_opts[:stored_fee_update_interval_minutes] == 60000
  end

  test "raises an ArgumentError when FEE_CHANGE_TOLERANCE_PERCENT is not a stingified integer" do
    :ok = System.put_env(@env_fee_adapter, "feed")

    :ok = System.put_env(@env_fee_change_tolerance_percent, "1.5")
    assert_raise ArgumentError, fn -> SetFeeFeedAdapterOpts.init([]) end

    :ok = System.put_env(@env_fee_change_tolerance_percent, "not integer")
    assert_raise ArgumentError, fn -> SetFeeFeedAdapterOpts.init([]) end
  end

  test "raises an ArgumentError when STORED_FEE_UPDATE_INTERVAL_MINUTES is not a stingified integer" do
    :ok = System.put_env(@env_fee_adapter, "feed")
    :ok = System.put_env(@env_stored_fee_update_interval_minutes, "not a number")

    :ok = System.put_env(@env_stored_fee_update_interval_minutes, "100.20")
    assert_raise ArgumentError, fn -> SetFeeFeedAdapterOpts.init([]) end

    :ok = System.put_env(@env_stored_fee_update_interval_minutes, "not integer")
    assert_raise ArgumentError, fn -> SetFeeFeedAdapterOpts.init([]) end
  end

  test "does not touch the configuration that's not present as env var" do
    original_opts = [
      fee_feed_url: "http://example.com/fee-feed-url-original",
      fee_change_tolerance_percent: 10,
      stored_fee_update_interval_minutes: 30
    ]

    :ok = Application.put_env(@app, @config_key, {FeedAdapter, opts: original_opts})

    # Intentionally not configuring @env_fee_feed_url and @env_stored_fee_update_interval_minutes
    :ok = System.put_env(@env_fee_adapter, "feed")
    :ok = System.put_env(@env_fee_change_tolerance_percent, "50")
    :ok = SetFeeFeedAdapterOpts.init([])

    {adapter, opts: adapter_opts} = Application.get_env(@app, @config_key)
    assert adapter == FeedAdapter
    assert adapter_opts[:fee_feed_url] == original_opts[:fee_feed_url]
    assert adapter_opts[:fee_change_tolerance_percent] == 50
    assert adapter_opts[:stored_fee_update_interval_minutes] == original_opts[:stored_fee_update_interval_minutes]
  end

  test "does not change the configuration when FEE_ADAPTER is not \"feed\"" do
    original_config = Application.get_env(@app, @config_key)

    :ok = System.put_env(@env_fee_adapter, "not_feed_adapter")
    :ok = System.put_env(@env_fee_feed_url, "http://example.com/fee-feed-url")
    :ok = System.put_env(@env_fee_change_tolerance_percent, "10")
    :ok = System.put_env(@env_stored_fee_update_interval_minutes, "60000")
    :ok = SetFeeFeedAdapterOpts.init([])

    assert Application.get_env(@app, @config_key) == original_config
  end

  test "no other configurations got affected", context do
    :ok = System.put_env(@env_fee_adapter, "feed")
    :ok = System.put_env(@env_fee_feed_url, "http://example.com/fee-feed-url")
    :ok = System.put_env(@env_fee_change_tolerance_percent, "10")
    :ok = System.put_env(@env_stored_fee_update_interval_minutes, "60000")
    :ok = SetFeeFeedAdapterOpts.init([])

    new_configs = @app |> Application.get_all_env() |> Keyword.delete(@config_key) |> Enum.sort()
    old_configs = context.original_config |> Keyword.delete(@config_key) |> Enum.sort()

    assert new_configs == old_configs
  end
end
