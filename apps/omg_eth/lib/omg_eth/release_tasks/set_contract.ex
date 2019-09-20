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
  @error "Set ETHEREUM_NETWORK to RINKEBY or LOCALCHAIN, *_TXHASH_CONTRACT, *_AUTHORITY_ADDRESS and *_CONTRACT_ADDRESS environment variables or CONTRACT_EXCHANGER_URL."

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
    exchanger = get_env("CONTRACT_EXCHANGER_URL")
    via_env = get_env("ETHEREUM_NETWORK")

    case {exchanger, via_env} do
      {exchanger, _} when is_binary(exchanger) ->
        _ =
          unless is_binary(via_env) && (String.upcase(via_env) == "RINKEBY" or String.upcase(via_env) == "LOCALCHAIN") do
            exit("Set ETHEREUM_NETWORK to RINKEBY and populate CONTRACT_EXCHANGER_URL")
          end

        _ = Application.ensure_all_started(:hackney)
        body = get_body_from_exchanger(exchanger)

        _ =
          unless is_binary(body) do
            exit("CONTRACT_EXCHANGER_URL is not reachable")
          end

        %{
          "authority_addr" => authority_address,
          "contract_addr" => contract_address,
          "txhash_contract" => txhash_contract
        } = Jason.decode!(body)

        exit_period_seconds =
          validate_integer(get_env("EXIT_PERIOD_SECONDS"), Application.get_env(@app, :exit_period_seconds))

        update_configuration(txhash_contract, authority_address, contract_address, exit_period_seconds)

      {_, via_env} when is_binary(via_env) ->
        :ok = apply_static_settings(via_env)

      _ ->
        exit(@error)
    end
  end

  defp apply_static_settings(network) do
    network =
      case String.upcase(network) do
        "RINKEBY" = network ->
          network

        "LOCALCHAIN" = network ->
          network

        _ ->
          exit(@error)
      end

    txhash_contract = get_env(network <> "_TXHASH_CONTRACT")
    authority_address = get_env(network <> "_AUTHORITY_ADDRESS")
    contract_address = get_env(network <> "_CONTRACT_ADDRESS")

    exit_period_seconds =
      validate_integer(get_env("EXIT_PERIOD_SECONDS"), Application.get_env(@app, :exit_period_seconds))

    update_configuration(txhash_contract, authority_address, contract_address, exit_period_seconds)
  end

  defp update_configuration(txhash_contract, authority_address, contract_address, exit_period_seconds)
       when is_binary(txhash_contract) and
              is_binary(authority_address) and is_binary(contract_address) and is_integer(exit_period_seconds) do
    :ok = Application.put_env(@app, :txhash_contract, String.downcase(txhash_contract), persistent: true)
    :ok = Application.put_env(@app, :authority_addr, String.downcase(authority_address), persistent: true)
    :ok = Application.put_env(@app, :contract_addr, String.downcase(contract_address), persistent: true)
    :ok = Application.put_env(@app, :exit_period_seconds, exit_period_seconds)
  end

  defp update_configuration(_, _, _, _), do: exit(@error)

  defp get_env(key), do: System.get_env(key)

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default

  defp get_body_from_exchanger(exchanger) do
    # maybe it's not up yet, let's give it 60 seconds
    get_body_from_exchanger(exchanger, 60)
  end

  defp get_body_from_exchanger(_, 0), do: {:error, :cant_reach_exchanger}

  defp get_body_from_exchanger(exchanger, count) do
    case HTTPoison.get(exchanger) do
      {:ok, %{body: body}} ->
        body

      _ ->
        :ok = Process.sleep(1_000)
        get_body_from_exchanger(exchanger, count - 1)
    end
  end
end
