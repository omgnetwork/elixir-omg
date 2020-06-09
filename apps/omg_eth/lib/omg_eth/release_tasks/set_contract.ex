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
  @behaviour Config.Provider
  require Logger

  alias OMG.Eth.Encoding
  alias OMG.Eth.RootChain.Abi
  alias OMG.Eth.RootChain.Rpc

  @networks ["RINKEBY", "ROPSTEN", "GOERLI", "KOVAN", "MAINNET", "LOCALCHAIN"]
  @error "Set ETHEREUM_NETWORK to #{Enum.join(@networks, ",")} with TXHASH_CONTRACT, AUTHORITY_ADDRESS and CONTRACT_ADDRESS environment variables or CONTRACT_EXCHANGER_URL."
  @ether_vault_id 1
  @erc20_vault_id 2
  @doc """
  The contract values can currently come either from ENV variables for deployments in
  - development
  - stagind
  - production
  or, they're manually deployed for local development:
  """

  def init(args) do
    args
  end

  def load(config, args) do
    _ = on_load()
    rpc_api = Keyword.get(args, :rpc_api, Rpc)

    exchanger = get_env("CONTRACT_EXCHANGER_URL")
    via_env = get_env("ETHEREUM_NETWORK")
    network = get_network(via_env)

    {txhash_contract, authority_address, plasma_framework} =
      case exchanger do
        exchanger when is_binary(exchanger) ->
          body =
            try do
              {:ok, %{body: body}} = HTTPoison.get(exchanger)
              body
            rescue
              reason -> exit("CONTRACT_EXCHANGER_URL #{exchanger} is not reachable because of #{inspect(reason)}")
            end

          %{
            authority_address: authority_address,
            plasma_framework: plasma_framework,
            plasma_framework_tx_hash: txhash_contract
          } = Jason.decode!(body, keys: :atoms!)

          {txhash_contract, authority_address, plasma_framework}

        _ ->
          txhash_contract = get_env("TXHASH_CONTRACT")
          authority_address = get_env("AUTHORITY_ADDRESS")
          plasma_framework = get_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK")
          {txhash_contract, authority_address, plasma_framework}
      end

    # get all the data from external sources
    {exit_games, eth_vault, erc20_vault, min_exit_period_seconds, contract_semver, child_block_interval} =
      get_external_data(plasma_framework, rpc_api)

    # Okay, so I am not sure if we want to keep payment_exit_game under contract_addr.
    # However, this is more backward competible with existing code. If we want to move away
    # for all the places we should refactor this.
    contract_addresses = %{
      plasma_framework: plasma_framework,
      eth_vault: eth_vault,
      erc20_vault: erc20_vault,
      payment_exit_game: exit_games.tx_payment_v1,
      payment_v2_exit_game: exit_games.tx_payment_v2
    }

    extra_config = %{
      txhash_contract: txhash_contract,
      authority_address: authority_address,
      contract_addresses: contract_addresses,
      exit_games: exit_games,
      min_exit_period_seconds: min_exit_period_seconds,
      contract_semver: contract_semver,
      network: network,
      child_block_interval: child_block_interval
    }

    {:ok, []} = valid_extra_config?(extra_config)
    merge_configuration(config, extra_config)
  end

  defp get_external_data(plasma_framework, rpc_api) do
    min_exit_period_seconds = get_min_exit_period(plasma_framework, rpc_api)

    # TODO: get the list of types from ex_plasma?
    exit_games =
      Enum.into(OMG.WireFormatTypes.exit_game_tx_types(), %{}, fn type ->
        {type,
         plasma_framework
         |> exit_game_contract_address(OMG.WireFormatTypes.tx_type_for(type), rpc_api)
         |> Encoding.to_hex()}
      end)

    eth_vault = plasma_framework |> get_vault(@ether_vault_id, rpc_api) |> Encoding.to_hex()
    erc20_vault = plasma_framework |> get_vault(@erc20_vault_id, rpc_api) |> Encoding.to_hex()
    contract_semver = get_contract_semver(plasma_framework, rpc_api)
    child_block_interval = get_child_block_interval(plasma_framework, rpc_api)
    {exit_games, eth_vault, erc20_vault, min_exit_period_seconds, contract_semver, child_block_interval}
  end

  defp merge_configuration(config, extra_config) do
    contract_addresses =
      Enum.into(
        extra_config.contract_addresses,
        %{},
        fn {name, addr} -> {name, String.downcase(addr)} end
      )

    Config.Reader.merge(config,
      omg_eth: [
        txhash_contract: String.downcase(extra_config.txhash_contract),
        authority_address: String.downcase(extra_config.authority_address),
        contract_addr: contract_addresses,
        exit_games: extra_config.exit_games,
        min_exit_period_seconds: extra_config.min_exit_period_seconds,
        contract_semver: extra_config.contract_semver,
        network: extra_config.network,
        child_block_interval: extra_config.child_block_interval
      ]
    )
  end

  defp get_min_exit_period(plasma_framework_contract, rpc_api) do
    signature = "minExitPeriod()"
    {:ok, data} = call(plasma_framework_contract, signature, [], rpc_api)
    %{"min_exit_period" => min_exit_period} = Abi.decode_function(data, signature)
    min_exit_period
  end

  defp get_contract_semver(plasma_framework_contract, rpc_api) do
    signature = "getVersion()"
    {:ok, data} = call(plasma_framework_contract, signature, [], rpc_api)
    %{"version" => version} = Abi.decode_function(data, signature)
    version
  end

  defp get_child_block_interval(plasma_framework_contract, rpc_api) do
    signature = "childBlockInterval()"
    {:ok, data} = call(plasma_framework_contract, signature, [], rpc_api)
    %{"child_block_interval" => child_block_interval} = Abi.decode_function(data, signature)
    child_block_interval
  end

  defp exit_game_contract_address(plasma_framework_contract, tx_type, rpc_api) do
    signature = "exitGames(uint256)"
    {:ok, data} = call(plasma_framework_contract, signature, [tx_type], rpc_api)
    %{"exit_game_address" => exit_game_address} = Abi.decode_function(data, signature)
    exit_game_address
  end

  defp get_vault(plasma_framework_contract, id, rpc_api) do
    signature = "vaults(uint256)"
    {:ok, data} = call(plasma_framework_contract, signature, [id], rpc_api)
    %{"vault_address" => vault_address} = Abi.decode_function(data, signature)
    vault_address
  end

  defp call(plasma_framework_contract, signature, args, rpc_api) do
    retries_left = 3
    call(plasma_framework_contract, signature, args, retries_left, rpc_api)
  end

  defp call(plasma_framework_contract, signature, args, 0, rpc_api) do
    rpc_api.call_contract(plasma_framework_contract, signature, args)
  end

  defp call(plasma_framework_contract, signature, args, retries_left, rpc_api) do
    case rpc_api.call_contract(plasma_framework_contract, signature, args) do
      {:ok, _data} = result ->
        result

      {:error, :closed} ->
        Process.sleep(1000)
        call(plasma_framework_contract, signature, args, retries_left - 1, rpc_api)
    end
  end

  defp get_env(key), do: System.get_env(key)

  defp get_network(nil), do: exit(@error)

  defp get_network(data) do
    case Enum.member?(@networks, String.upcase(data)) do
      true ->
        String.upcase(data)

      _ ->
        exit(@error)
    end
  end

  defp on_load() do
    {:ok, _} = Application.ensure_all_started(:logger)
    {:ok, _} = Application.ensure_all_started(:ethereumex)
  end

  defp valid_extra_config?(extra_config) do
    {_, validation_result} =
      {extra_config, {:ok, []}}
      |> valid_field?(:txhash_contract, &is_binary/1)
      |> valid_field?(:authority_address, &is_binary/1)
      |> valid_field?(:contract_addresses, &is_map/1)
      |> valid_field?(:exit_games, &is_map/1)
      |> valid_field?(:min_exit_period_seconds, &is_integer/1)
      |> valid_field?(:contract_semver, &is_binary/1)
      |> valid_field?(:network, &is_binary/1)
      |> valid_field?(:child_block_interval, &is_integer/1)

    validation_result
  end

  defp valid_field?(validation_state, field, validation_function) do
    {extra_config, {status, invalid_fields}} = validation_state
    field_data = extra_config[field]

    case field_data != nil && validation_function.(field_data) do
      true -> {extra_config, {status, invalid_fields}}
      false -> {extra_config, {:invalid_extra_config, [field | invalid_fields]}}
    end
  end
end
