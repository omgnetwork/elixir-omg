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
  @moduledoc false
  use Distillery.Releases.Config.Provider
  require Logger

  @app :omg_child_chain
  @config_key :fee_adapter_opts

  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)

    if OMG.ChildChain.Fees.FeedAdapter == Application.get_env(@app, :fee_adapter) do
      adapter_opts =
        @app
        |> Application.fetch_env!(@config_key)
        |> replace_with_env(&validate_string/2, feed_url: "FEE_FEED_URL")
        |> replace_with_env(&validate_integer/2, fee_change_tolerance_percent: "FEE_FEED_TOLERANCE_PERCENT")
        |> replace_with_env(&validate_integer/2, stored_fee_update_interval_minutes: "FEE_FEED_UPDATE_INTERVAL_MINUTES")

      :ok = Application.put_env(@app, @config_key, adapter_opts, persistent: true)
      _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@config_key} Value: #{inspect(adapter_opts)}.")
    end

    :ok
  end

  defp validate_string(value, _default) when is_binary(value), do: value
  defp validate_string(_, default), do: default

  defp validate_integer(value, default), do: value |> validate_string(default) |> String.to_integer()

  defp replace_with_env(opts, validator_fn, opts_key_env),
    do:
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
