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

defmodule OMG.Eth.ReleaseTasks.SetEthereumHeightCheckInterval do
  @moduledoc """
  Configures the interval to check for new events from Ethereum, including checking for new heights.

  This is essentially the same as `OMG.ReleaseTasks.SetEthereumEventsCheckInterval` but for a different subapp.
  """
  use Distillery.Releases.Config.Provider
  require Logger

  @app :omg_eth
  @env_key "ETHEREUM_EVENTS_CHECK_INTERVAL_MS"
  @config_key @ethereum_events_check_interval_ms

  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)

    interval_ms = get_interval_ms()
    :ok = Application.put_env(@app, @config_key, interval_ms, persistent: true)
  end

  defp get_interval_ms() do
    interval_ms =
      validate_integer(
        get_env(@env_key),
        Application.get_env(@app, @config_key)
      )

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@config_key} Value: #{inspect(interval_ms)}.")

    interval_ms
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default
end
