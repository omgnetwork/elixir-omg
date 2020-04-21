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

defmodule OMG.ChildChain.ReleaseTasks.SetFeeFeedAdapterOpts do
  @moduledoc """
  Detects if `FEE_ADAPTER` is set to `"FEED"` (case-insensitive). If so, it sets the system's
  fee adapter to FeedAdapter and configures it with values from related environment variables.
  """
  @behaviour Config.Provider
  require Logger

  @app :omg_child_chain
  @config_key :fee_adapter
  @env_fee_adapter "FEE_ADAPTER"

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = on_load()
    adapter_config = config[@app][@config_key]

    updated_config =
      @env_fee_adapter
      |> System.get_env()
      |> parse_adapter_value()
      |> case do
        "FEED" -> [omg_child_chain: [fee_adapter: configure_adapter(adapter_config)]]
        _ -> []
      end

    Config.Reader.merge(config, updated_config)
  end

  defp parse_adapter_value(nil), do: :skip
  defp parse_adapter_value(value), do: String.upcase(value)

  # If the existing config is already a feed adapter, we merge the new config into the existing opts.
  # If it's not a feed adapter, we start configuring with an empty FeedAdapter opts.
  defp configure_adapter({OMG.ChildChain.Fees.FeedAdapter, opts: fee_adapter_opts}) do
    adapter_opts =
      fee_adapter_opts
      |> replace_with_env(:fee_feed_url, "FEE_FEED_URL")
      |> replace_with_env(:fee_change_tolerance_percent, "FEE_CHANGE_TOLERANCE_PERCENT", &validate_integer/1)
      |> replace_with_env(
        :stored_fee_update_interval_minutes,
        "STORED_FEE_UPDATE_INTERVAL_MINUTES",
        &validate_integer/1
      )

    adapter = {OMG.ChildChain.Fees.FeedAdapter, opts: adapter_opts}
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@config_key} Value: #{inspect(adapter)}.")
    adapter
  end

  defp configure_adapter(_not_feed_adapter) do
    configure_adapter({OMG.ChildChain.Fees.FeedAdapter, opts: []})
  end

  defp validate_integer(value), do: String.to_integer(value)

  # Replaces one of the adapter's options value with environment variable when set.
  #
  # E.g. called with following parameters:
  # - opts: [fee_feed_url: "localhost", fee_change_tolerance_percent: 25]
  # - config_key: :fee_feed_url
  # - env_var_name: "FEE_FEED_URL"
  # - validator function: &validate_string/2
  #
  # assuming "FEE_FEED_URL" environment variable is set to "http://childchain:9656"
  # When the env var isn't set, value of the given option's key remains unchainched.
  #
  # Returns the options with `fee_feed_url` value replaced with the value of env var:
  # [fee_feed_url: "http://childchain:9656", fee_change_tolerance_percent: 25]
  defp replace_with_env(opts, config_key, env_var_name, validator \\ nil) do
    value =
      case {System.get_env(env_var_name), validator} do
        {nil, _} ->
          opts[config_key]

        {raw_value, nil} ->
          raw_value

        {raw_value, validator} ->
          validator.(raw_value)
      end

    Keyword.put(opts, config_key, value)
  end

  defp on_load() do
    _ = Application.ensure_all_started(:logger)
    _ = Application.load(@app)
  end
end
