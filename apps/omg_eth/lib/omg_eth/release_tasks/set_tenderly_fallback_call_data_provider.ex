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

defmodule OMG.Eth.ReleaseTasks.SetTenderlyFallbackCallDataProvider do
  @moduledoc false
  @behaviour Config.Provider
  require Logger

  @doc """
  Configures tenderly fallback call data provider
  """
  @app :omg_eth

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = Application.ensure_all_started(:logger)
    tenderly_app_config = Application.get_env(@app, OMG.Eth.Tenderly.Client, [])

    tenderly_project_url = get_tenderly_project_url(tenderly_app_config)
    access_key = get_access_key(tenderly_app_config)
    network_id = get_network_id(tenderly_app_config)

    tenderly_config = [tenderly_project_url: tenderly_project_url, access_key: access_key, network_id: network_id]

    Config.Reader.merge(config, omg_eth: ["Elixir.OMG.Eth.Tenderly.Client": tenderly_config])
  end

  defp get_tenderly_project_url(tenderly_app_config) do
    url =
      validate_string(System.get_env("TENDERLY_PROJECT_URL"), Keyword.get(tenderly_app_config, :tenderly_project_url))

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: TENDERLY_PROJECT_URL Value: #{inspect(url)}.")

    url
  end

  defp get_access_key(tenderly_app_config) do
    access_key = validate_string(System.get_env("TENDERLY_ACCESS_KEY"), Keyword.get(tenderly_app_config, :access_key))
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: TENDERLY_ACCESS_KEY is set.")

    access_key
  end

  defp get_network_id(tenderly_app_config) do
    network_id = validate_string(System.get_env("TENDERLY_NETWORK_ID"), Keyword.get(tenderly_app_config, :network_id))
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: TENDERLY_NETWORK_ID Value: #{inspect(network_id)}.")

    network_id
  end

  defp validate_string(value, _default) when is_binary(value), do: value
  defp validate_string(_, default), do: default
end
