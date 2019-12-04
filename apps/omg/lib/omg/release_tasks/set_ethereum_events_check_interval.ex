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
  @moduledoc false
  use Distillery.Releases.Config.Provider
  require Logger
  @app :omg

  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)

    ethereum_events_check_interval_ms = ethereum_events_check_interval_ms()

    :ok =
      Application.put_env(@app, :ethereum_events_check_interval_ms, ethereum_events_check_interval_ms, persistent: true)
  end

  defp ethereum_events_check_interval_ms() do
    ethereum_events_check_interval_ms =
      validate_integer(
        get_env("ETHEREUM_EVENTS_CHECK_INTERVAL_MS"),
        Application.get_env(@app, :ethereum_events_check_interval_ms)
      )

    _ =
      Logger.info(
        "CONFIGURATION: App: #{@app} Key: ethereum_events_check_interval_ms Value: #{
          inspect(ethereum_events_check_interval_ms)
        }."
      )

    ethereum_events_check_interval_ms
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default
end
