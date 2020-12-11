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

defmodule OMG.Eth.ReleaseTasks.SetEthereumBlockTime do
  @moduledoc """
  Configures the average ethereum block time for the network used.
  """
  @behaviour Config.Provider
  require Logger

  @app :omg_eth
  @env_key "ETHEREUM_BLOCK_TIME_SECONDS"

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = on_load()
    ethereum_block_time = get_ethereum_block_time()
    Config.Reader.merge(config, omg_eth: [ethereum_block_time_seconds: ethereum_block_time])
  end

  defp get_ethereum_block_time() do
    ethereum_block_time_seconds = Application.get_env(@app, :ethereum_block_time_seconds)
    ethereum_block_time_seconds = validate_integer(get_env(@env_key), ethereum_block_time_seconds)

    _ =
      Logger.info(
        "CONFIGURATION: App: #{@app} Key: ethereum_block_time_seconds Value: #{inspect(ethereum_block_time_seconds)}."
      )

    ethereum_block_time_seconds
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default

  defp on_load() do
    _ = Application.ensure_all_started(:logger)
    _ = Application.load(@app)
  end
end
