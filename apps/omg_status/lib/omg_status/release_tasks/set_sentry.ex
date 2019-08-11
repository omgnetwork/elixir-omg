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

defmodule OMG.Status.ReleaseTasks.SetSentry do
  @moduledoc false
  use Distillery.Releases.Config.Provider
  require Logger
  @app :sentry
  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)
    app_env = System.get_env("APP_ENV")
    sentry_dsn = System.get_env("SENTRY_DSN")

    :ok =
      case {is_binary(app_env), is_binary(sentry_dsn)} do
        {true, true} ->
          hostname = get_hostname()

          _ =
            Logger.warn(
              "Sentry configuration provided. Enabling Sentry with APP ENV #{inspect(app_env)}, with SENTRY_DSN #{
                inspect(sentry_dsn)
              }, with HOSTNAME (server_name) #{inspect(hostname)}"
            )

          :ok = Application.put_env(@app, :dsn, sentry_dsn, persistent: true)
          :ok = Application.put_env(@app, :environment_name, app_env, persistent: true)
          :ok = Application.put_env(@app, :included_environments, [app_env], persistent: true)
          :ok = Application.put_env(@app, :server_name, hostname)

          :ok =
            Application.put_env(@app, :server_name, %{
              application: get_application(),
              eth_network: get_env("ETHEREUM_NETWORK"),
              eth_node: get_rpc_client_type()
            })

        _ ->
          _ =
            Logger.warn(
              "Sentry configuration not provided. Disabling Sentry. If you want it enabled provide APP_ENV and SENTRY_DSN."
            )

          Application.put_env(@app, :included_environments, [], persistent: true)
      end
  end

  defp get_hostname do
    hostname =
      validate_string(
        get_env("HOSTNAME"),
        Application.get_env(@app, :server_name)
      )

    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: HOSTNAME, server_name Value: #{inspect(hostname)}.")
    hostname
  end

  defp get_application do
    app =
      case :code.ensure_loaded(OMG.Watcher) do
        true -> :watcher
        _ -> :child_chain
      end

    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: application Value: #{inspect(app)}.")
    app
  end

  defp get_rpc_client_type do
    rpc_client_type = validate_rpc_client_type(get_env("ETH_NODE"), Application.get_env(@app, :tags)[:eth_node])
    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: ETH_NODE Value: #{inspect(rpc_client_type)}.")

    rpc_client_type
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_rpc_client_type(value, default) when is_binary(value),
    do: to_rpc_client_type(String.upcase(value), default)

  defp validate_rpc_client_type(_value, default),
    do: default

  defp to_rpc_client_type("GETH", _), do: "geth"
  defp to_rpc_client_type("PARITY", _), do: "parity"
  defp to_rpc_client_type(_, default), do: default

  defp validate_string(value, _default) when is_binary(value), do: value
  defp validate_string(_, default), do: default
end
