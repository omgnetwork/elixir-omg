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

defmodule OMG.Eth.ReleaseTasks.SetContract do
  @moduledoc false
  use Distillery.Releases.Config.Provider
  require Logger
  @app :omg_eth
  @doc """
  The contract values can currently come either from ENV variables for deployments in
  - development
  - stagind
  - production
  or, they're manually deployed for local development:
  """
  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)

    case get_env("CONTRACT_EXCHANGER_URL") do
      value when is_binary(value) ->
        _ = Application.ensure_all_started(:hackney)
        {:ok, %{body: body}} = HTTPoison.get(value)

        %{
          "authority_addr" => authority_address,
          "contract_addr" => contract_address,
          "txhash_contract" => txhash_contract
        } = Jason.decode!(body)

        exit_period_seconds =
          validate_integer(get_env("EXIT_PERIOD_SECONDS"), Application.get_env(@app, :exit_period_seconds))

        :ok = Application.put_env(@app, :txhash_contract, String.downcase(txhash_contract), persistent: true)
        :ok = Application.put_env(@app, :authority_addr, String.downcase(authority_address), persistent: true)
        :ok = Application.put_env(@app, :contract_addr, String.downcase(contract_address), persistent: true)
        :ok = Application.put_env(@app, :exit_period_seconds, exit_period_seconds)

      _ ->
        case String.upcase(get_env("ETHEREUM_NETWORK")) do
          "RINKEBY" = network ->
            :ok = apply_settings(network)

          _ ->
            error =
              "Set ETHEREUM_NETWORK, RINKEBY_TXHASH_CONTRACT, RINKEBY_AUTHORITY_ADDRESS and RINKEBY_CONTRACT_ADDRESS environment variables or CONTRACT_EXCHANGER_URL."

            exit(error)
        end

        :ok
    end
  end

  defp apply_settings(network) do
    txhash_contract = get_env(network <> "_TXHASH_CONTRACT")
    authority_address = get_env(network <> "_AUTHORITY_ADDRESS")
    contract_address = get_env(network <> "_CONTRACT_ADDRESS")

    exit_period_seconds =
      validate_integer(get_env("EXIT_PERIOD_SECONDS"), Application.get_env(@app, :exit_period_seconds))

    :ok = Application.put_env(@app, :txhash_contract, txhash_contract, persistent: true)
    :ok = Application.put_env(@app, :authority_addr, authority_address, persistent: true)
    :ok = Application.put_env(@app, :contract_addr, contract_address, persistent: true)
    :ok = Application.put_env(@app, :exit_period_seconds, exit_period_seconds)
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default
end
