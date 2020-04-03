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

defmodule OMG.Eth.ReleaseTasks.SetEthereumClient do
  @moduledoc false
  @behaviour Config.Provider
  require Logger
  @app :omg_eth
  @doc """
  Gets the environment setting for the ethereum client location.
  """

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = on_load()
    rpc_url = get_ethereum_rpc_url()
    rpc_client_type = get_rpc_client_type()
    # we need to get this imidiatelly in effect because we use ethereumex in SetContract
    Application.put_env(:ethereumex, :url, rpc_url, persistent: true)

    Config.Reader.merge(config,
      ethereumex: [url: rpc_url],
      omg_eth: [eth_node: rpc_client_type]
    )
  end

  defp get_ethereum_rpc_url() do
    url = validate_string(get_env("ETHEREUM_RPC_URL"), Application.get_env(:ethereumex, :url))
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: ETHEREUM_RPC_URL Value: #{inspect(url)}.")

    url
  end

  defp get_rpc_client_type() do
    rpc_client_type = validate_rpc_client_type(get_env("ETH_NODE"), Application.get_env(@app, :eth_node))
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: ETH_NODE Value: #{inspect(rpc_client_type)}.")

    rpc_client_type
  end

  defp validate_rpc_client_type(value, _default) when is_binary(value),
    do: to_rpc_client_type(String.upcase(value))

  defp validate_rpc_client_type(_value, default),
    do: default

  defp to_rpc_client_type("GETH"), do: :geth
  defp to_rpc_client_type("PARITY"), do: :parity
  defp to_rpc_client_type("INFURA"), do: :infura
  defp to_rpc_client_type(_), do: exit("You need to choose between geth, parity or infura.")

  defp validate_string(value, _default) when is_binary(value), do: value
  defp validate_string(_, default), do: default

  defp get_env(key), do: System.get_env(key)

  defp on_load() do
    _ = Application.ensure_all_started(:logger)
    _ = Application.ensure_all_started(:omg_status)
    _ = Application.load(@app)
    _ = Application.load(:ethereumex)
  end
end
