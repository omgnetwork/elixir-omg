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

defmodule OMG.Status.ReleaseTasks.SetSentry do
  @moduledoc false

  @behaviour Config.Provider
  require Logger

  @app :sentry

  def init(args) do
    args
  end

  def load(config, release: release, current_version: current_version) do
    _ = Application.ensure_all_started(:logger)
    app_env = get_app_env()
    sentry_dsn = System.get_env("SENTRY_DSN")

    case is_binary(sentry_dsn) do
      true ->
        hostname = get_hostname()

        _ =
          Logger.warn(
            "Sentry configuration provided. Enabling Sentry with APP ENV #{inspect(app_env)}, with SENTRY_DSN #{
              inspect(sentry_dsn)
            }, with HOSTNAME (server_name) #{inspect(hostname)}"
          )

        Config.Reader.merge(
          config,
          sentry: [
            dsn: sentry_dsn,
            environment_name: app_env,
            included_environments: [app_env],
            server_name: hostname,
            tags: %{
              application: release,
              eth_network: get_env("ETHEREUM_NETWORK"),
              eth_node: get_rpc_client_type(),
              current_version: "vsn-#{current_version}",
              app_env: "#{app_env}",
              hostname: "#{hostname}"
            }
          ]
        )

      _ ->
        _ =
          Logger.warn(
            "Sentry configuration not provided. Disabling Sentry. If you want it enabled provide APP_ENV and SENTRY_DSN."
          )

        Config.Reader.merge(config, sentry: [included_environments: []])
    end
  end

  defp get_app_env() do
    env = validate_string(get_env("APP_ENV"), Application.get_env(@app, :environment_name))
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: APP_ENV Value: #{inspect(env)}.")
    env
  end

  defp get_hostname() do
    hostname = validate_string(get_env("HOSTNAME"), Application.get_env(@app, :server_name))

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: HOSTNAME, server_name Value: #{inspect(hostname)}.")
    hostname
  end

  defp get_rpc_client_type() do
    rpc_client_type = validate_rpc_client_type(get_env("ETH_NODE"), Application.get_env(@app, :tags)[:eth_node])
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: ETH_NODE Value: #{inspect(rpc_client_type)}.")

    rpc_client_type
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_rpc_client_type(value, _default) when is_binary(value),
    do: to_rpc_client_type(String.upcase(value))

  defp validate_rpc_client_type(_value, default),
    do: default

  defp to_rpc_client_type("GETH"), do: :geth
  defp to_rpc_client_type("PARITY"), do: :parity
  defp to_rpc_client_type("INFURA"), do: :infura
  defp to_rpc_client_type(_), do: exit("ETH_NODE must be either GETH, PARITY or INFURA.")

  defp validate_string(value, _default) when is_binary(value), do: value
  defp validate_string(_, default), do: default
end
