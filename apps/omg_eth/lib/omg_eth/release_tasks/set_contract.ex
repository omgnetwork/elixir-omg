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
  @error "Set ETHEREUM_NETWORK to RINKEBY or LOCALCHAIN, *_TXHASH_CONTRACT, *_AUTHORITY_ADDRESS and *_CONTRACT_ADDRESS_* environment variables or CONTRACT_EXCHANGER_URL."

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

        body =
          try do
            {:ok, %{body: body}} = HTTPoison.get(exchanger)
            body
          rescue
            reason -> exit("CONTRACT_EXCHANGER_URL #{exchanger} is not reachable because of #{inspect(reason)}")
          end

        %{
          authority_address: authority_address,
          erc20_vault: erc20_vault,
          eth_vault: eth_vault,
          payment_exit_game: payment_exit_game,
          plasma_framework: plasma_framework,
          plasma_framework_tx_hash: txhash_contract
        } = Jason.decode!(body, keys: :atoms!)

        exit_period_seconds =
          validate_integer(get_env("MIN_EXIT_PERIOD"), Application.get_env(@app, :exit_period_seconds))

        contract_addresses = %{
          plasma_framework: plasma_framework,
          eth_vault: eth_vault,
          erc20_vault: erc20_vault,
          payment_exit_game: payment_exit_game
        }

        update_configuration(txhash_contract, authority_address, contract_addresses, exit_period_seconds)

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
    env_contract_address_plasma_framework = get_env(network <> "_CONTRACT_ADDRESS_PLASMA_FRAMEWORK")
    env_contract_address_eth_vault = get_env(network <> "_CONTRACT_ADDRESS_ETH_VAULT")
    env_contract_address_erc20_vault = get_env(network <> "_CONTRACT_ADDRESS_ERC20_VAULT")
    env_contract_address_payment_exit_game = get_env(network <> "_CONTRACT_ADDRESS_PAYMENT_EXIT_GAME")

    contract_addresses = %{
      plasma_framework: env_contract_address_plasma_framework,
      eth_vault: env_contract_address_eth_vault,
      erc20_vault: env_contract_address_erc20_vault,
      payment_exit_game: env_contract_address_payment_exit_game
    }

    exit_period_seconds =
      validate_integer(get_env("MIN_EXIT_PERIOD"), Application.get_env(@app, :exit_period_seconds))

    update_configuration(txhash_contract, authority_address, contract_addresses, exit_period_seconds)
  end

  defp update_configuration(txhash_contract, authority_address, contract_addresses, exit_period_seconds)
       when is_binary(txhash_contract) and
              is_binary(authority_address) and is_map(contract_addresses) and is_integer(exit_period_seconds) do
    contract_addresses = Enum.into(contract_addresses, %{}, fn {name, addr} -> {name, String.downcase(addr)} end)
    :ok = Application.put_env(@app, :txhash_contract, String.downcase(txhash_contract), persistent: true)
    :ok = Application.put_env(@app, :authority_addr, String.downcase(authority_address), persistent: true)
    :ok = Application.put_env(@app, :contract_addr, contract_addresses, persistent: true)
    :ok = Application.put_env(@app, :exit_period_seconds, exit_period_seconds)
  end

  defp update_configuration(_, _, _, _), do: exit(@error)

  defp get_env(key), do: System.get_env(key)

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default
end
