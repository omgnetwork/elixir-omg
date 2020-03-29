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

defmodule OMG.Eth.ReleaseTasks.SetEthereumBlockTime do
  @moduledoc """
  Configures the average ethereum block time for the network used.
  """
  @behaviour Config.Provider
  require Logger

  @app :omg_eth
  @env_key "ETHEREUM_BLOCK_TIME_SECONDS"
  @config_key :ethereum_block_time_seconds

  def init(_args) do
    _ = Application.ensure_all_started(:logger)
    :ok = Application.put_env(@app, @config_key, get_ethereum_block_time(), persistent: true)
  end

  defp get_ethereum_block_time() do
    ethereum_block_time_seconds =
      validate_integer(
        get_env(@env_key),
        Application.get_env(@app, @config_key)
      )

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@config_key} Value: #{inspect(ethereum_block_time_seconds)}.")

    ethereum_block_time_seconds
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default
end
