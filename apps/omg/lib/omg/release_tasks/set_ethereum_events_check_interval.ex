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

defmodule OMG.ReleaseTasks.SetEthereumEventsCheckInterval do
  @moduledoc """
  Configures the interval to check for new events from Ethereum.

  This is essentially the same as `OMG.Eth.ReleaseTasks.SetEthereumEventsCheckInterval` but for a different subapp.
  """
  @behaviour Config.Provider
  require Logger

  @app :omg
  @env_key "ETHEREUM_EVENTS_CHECK_INTERVAL_MS"

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = Application.ensure_all_started(:logger)

    interval_ms = get_interval_ms()

    Config.Reader.merge(config,
      omg: [ethereum_events_check_interval_ms: interval_ms]
    )
  end

  defp get_interval_ms() do
    interval_ms =
      validate_integer(
        get_env(@env_key),
        Application.get_env(@app, :ethereum_events_check_interval_ms)
      )

    _ =
      Logger.info("CONFIGURATION: App: #{@app} Key: ethereum_events_check_interval_ms Value: #{inspect(interval_ms)}.")

    interval_ms
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default
end
