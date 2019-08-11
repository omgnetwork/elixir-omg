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
  use Distillery.Releases.Config.Provider
  require Logger
  @app :omg_eth
  @doc """
  Gets the environment setting for the ethereum client location.
  """
  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)
    rpc_url = get_ethereum_rpc_url()
    Application.put_env(:ethereumex, :url, rpc_url, persistent: true)

    ws_url = get_ethereum_ws_rpc_url()
    Application.put_env(@app, :ws_url, ws_url, persistent: true)

    rpc_client_type = get_rpc_client_type()
    Application.put_env(@app, :eth_node, rpc_client_type, persistent: true)
    :ok
  end

  defp get_ethereum_rpc_url do
    url = validate_string(get_env("ETHEREUM_RPC_URL"), Application.get_env(:ethereumex, :url))
    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: ETHEREUM_RPC_URL Value: #{inspect(url)}.")

    url
  end

  defp get_ethereum_ws_rpc_url do
    url = validate_string(get_env("ETHEREUM_WS_RPC_URL"), Application.get_env(:omg_eth, :ws_url))

    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: ETHEREUM_WS_RPC_URL Value: #{inspect(url)}.")

    url
  end

  defp get_rpc_client_type do
    rpc_client_type = validate_rpc_client_type(get_env("ETH_NODE"), Application.get_env(@app, :eth_node))
    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: ETH_NODE Value: #{inspect(rpc_client_type)}.")

    rpc_client_type
  end

  defp validate_rpc_client_type(value, default) when is_binary(value),
    do: to_rpc_client_type(String.upcase(value), default)

  defp validate_rpc_client_type(_value, default),
    do: default

  defp to_rpc_client_type("GETH", _), do: "geth"
  defp to_rpc_client_type("PARITY", _), do: "parity"
  defp to_rpc_client_type(_, default), do: default

  defp validate_string(value, _default) when is_binary(value), do: value
  defp validate_string(_, default), do: default

  defp get_env(key), do: System.get_env(key)

  defp print_msg(msg) when is_binary(msg) do
    if IO.ANSI.enabled?() do
      IO.puts(IO.ANSI.format([IO.ANSI.red(), msg, IO.ANSI.reset()]))
    else
      IO.puts(msg)
    end
  end
end
