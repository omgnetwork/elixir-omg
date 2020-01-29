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

defmodule OMG.Eth.ReleaseTasks.SetEthereumStalledSyncThreshold do
  @moduledoc false
  use Distillery.Releases.Config.Provider
  require Logger

  @app :omg_eth
  @config_key :ethereum_stalled_sync_threshold_ms
  @env_name "ETHEREUM_STALLED_SYNC_THRESHOLD_MS"

  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)
    threshold_ms = stalled_sync_threshold_ms()

    :ok = Application.put_env(@app, @config_key, threshold_ms, persistent: true)
  end

  defp stalled_sync_threshold_ms() do
    threshold_ms =
      validate_integer(
        get_env(@env_name),
        Application.get_env(@app, @config_key)
      )

    _ =
      Logger.info(
        "CONFIGURATION: App: #{@app} Key: #{@config_key} Value: #{inspect(threshold_ms)}."
      )

    threshold_ms
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default
end
