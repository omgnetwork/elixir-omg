# Copyright 2019-2019 OMG Network Pte Ltd
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
  @behaviour Config.Provider
  require Logger

  @app :omg_eth
  @env_name "ETHEREUM_STALLED_SYNC_THRESHOLD_MS"

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = on_load()
    threshold_ms = stalled_sync_threshold_ms()
    Config.Reader.merge(config, omg_eth: [ethereum_stalled_sync_threshold_ms: threshold_ms])
  end

  defp stalled_sync_threshold_ms() do
    ethereum_stalled_sync_threshold_ms = Application.get_env(@app, :ethereum_stalled_sync_threshold_ms)
    threshold_ms = validate_integer(get_env(@env_name), ethereum_stalled_sync_threshold_ms)

    _ =
      Logger.info(
        "CONFIGURATION: App: #{@app} Key: ethereum_stalled_sync_threshold_ms Value: #{inspect(threshold_ms)}."
      )

    threshold_ms
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default

  defp on_load() do
    _ = Application.ensure_all_started(:logger)
    _ = Application.load(@app)
  end
end
