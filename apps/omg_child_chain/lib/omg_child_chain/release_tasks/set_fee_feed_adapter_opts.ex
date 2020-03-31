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
  use Distillery.Releases.Config.Provider
  require Logger

  @app :omg_child_chain
  @config_key :fee_adapter
  @env_fee_adapter "FEE_ADAPTER"

  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)
    existing_config = Application.get_env(@app, @config_key)

    @env_fee_adapter
    |> System.get_env()
    |> parse_adapter_value()
    |> case do
      "FEED" -> configure_feed_adapter(existing_config)
      _ -> :ok
    end
  end

  defp parse_adapter_value(nil), do: :skip
  defp parse_adapter_value(value), do: String.upcase(value)

  # If the existing config is already a feed adapter, we merge the new config into the existing opts.
  defp configure_feed_adapter({OMG.ChildChain.Fees.FeedAdapter, opts: fee_adapter_opts}) do
    adapter_opts =
      fee_adapter_opts
      |> replace_with_env(&validate_string/2, fee_feed_url: "FEE_FEED_URL")
      |> replace_with_env(&validate_integer/2, fee_change_tolerance_percent: "FEE_CHANGE_TOLERANCE_PERCENT")
      |> replace_with_env(&validate_integer/2, stored_fee_update_interval_minutes: "STORED_FEE_UPDATE_INTERVAL_MINUTES")

    new_value = {OMG.ChildChain.Fees.FeedAdapter, opts: adapter_opts}
    :ok = Application.put_env(@app, @config_key, adapter_opts, persistent: true)

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@config_key} Value: #{inspect(new_value)}.")

    :ok
  end

  # If the existing config is not a feed adapter, we start configuring with an empty opts.
  defp configure_feed_adapter(_existing_config) do
    configure_feed_adapter({OMG.ChildChain.Fees.FeedAdapter, opts: []})
  end

  defp validate_string(value, _default) when is_binary(value), do: value
  defp validate_string(_, default), do: default

  defp validate_integer(value, default), do: value |> validate_string(default) |> String.to_integer()

  # Replaces one of the adapter's options value with environment variable when set.
  #
  # E.g. called with following parameters:
  # - opts: [fee_feed_url: "localhost", fee_change_tolerance_percent: 25]
  # - validator function: &validate_string/2
  # - opts_key_env: fee_feed_url: "FEE_FEED_URL"
  #
  # assuming "FEE_FEED_URL" environment variable is set to "http://childchain:9656"
  # When the env var isn't set, value of the given option's key remains unchainched.
  #
  # Returns the options with `fee_feed_url` value replaced with the value of env var:
  # [fee_feed_url: "http://childchain:9656", fee_change_tolerance_percent: 25]
  defp replace_with_env(opts, validator_fn, opts_key_env) do
    Keyword.merge(
      opts,
      opts_key_env,
      fn _k, curr, env_name ->
        env_name
        |> System.get_env()
        |> validator_fn.(curr)
      end
    )
  end
end
