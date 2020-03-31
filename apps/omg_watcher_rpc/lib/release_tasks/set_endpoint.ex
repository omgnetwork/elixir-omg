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

defmodule OMG.WatcherRPC.ReleaseTasks.SetEndpoint do
  @moduledoc false
  @behaviour Config.Provider
  require Logger
  @app :omg_watcher_rpc

  def init(args) do
    args
  end

  def load(_config, _args) do
    _ = Application.ensure_all_started(:logger)
    config = Application.get_env(@app, OMG.WatcherRPC.Web.Endpoint)

    config =
      Keyword.put(
        config,
        :http,
        List.foldl(config[:http], [], fn
          {:port, _num}, acc -> [get_port() | acc]
          other, acc -> [other | acc]
        end)
      )

    config =
      Keyword.put(
        config,
        :url,
        List.foldl(config[:url], [], fn
          {:host, _num}, acc -> [get_hostname() | acc]
          other, acc -> [other | acc]
        end)
      )

    :ok = Application.put_env(@app, OMG.WatcherRPC.Web.Endpoint, Enum.sort(config), persistent: true)
  end

  defp get_port() do
    port =
      validate_integer(
        get_env("PORT"),
        Keyword.get(Application.get_env(@app, OMG.WatcherRPC.Web.Endpoint)[:http], :port)
      )

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: PORT Value: #{inspect(port)}.")
    {:port, port}
  end

  defp get_hostname() do
    hostname =
      validate_string(
        get_env("HOSTNAME"),
        Keyword.get(Application.get_env(@app, OMG.WatcherRPC.Web.Endpoint)[:url], :host)
      )

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: HOSTNAME Value: #{inspect(hostname)}.")
    {:host, hostname}
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default

  defp validate_string(value, _default) when is_binary(value), do: value
  defp validate_string(_, default), do: default
end
