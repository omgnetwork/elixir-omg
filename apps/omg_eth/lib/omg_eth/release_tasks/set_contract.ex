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

  alias OMG.Eth.Encoding
  alias OMG.Eth.RootChain.Abi
  alias OMG.Eth.RootChain.Rpc

  @app :omg_eth
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

  @impl Provider
  def init(_args) do
    {:ok, logger_apps} = Application.ensure_all_started(:logger)
    {:ok, ethereumex_apps} = Application.ensure_all_started(:ethereumex)

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
    {payment_exit_game, eth_vault, erc20_vault, min_exit_period_seconds, contract_semver, child_block_interval} =
      get_external_data(plasma_framework)

    contract_addresses = %{
      plasma_framework: plasma_framework,
      eth_vault: eth_vault,
      erc20_vault: erc20_vault,
      payment_exit_game: payment_exit_game
    }

    update_configuration(
      txhash_contract,
      authority_address,
      contract_addresses,
      min_exit_period_seconds,
      contract_semver,
      network,
      child_block_interval
    )

    (logger_apps ++ ethereumex_apps) |> Enum.reverse() |> Enum.each(&Application.stop/1)
  end

  defp get_external_data(plasma_framework) do
    min_exit_period_seconds = get_min_exit_period(plasma_framework)
    payment_exit_game = plasma_framework |> exit_game_contract_address(ExPlasma.payment_v1()) |> Encoding.to_hex()
    eth_vault = plasma_framework |> get_vault(@ether_vault_id) |> Encoding.to_hex()
    erc20_vault = plasma_framework |> get_vault(@erc20_vault_id) |> Encoding.to_hex()
    contract_semver = get_contract_semver(plasma_framework)
    child_block_interval = get_child_block_interval(plasma_framework)
    {payment_exit_game, eth_vault, erc20_vault, min_exit_period_seconds, contract_semver, child_block_interval}
  end

  defp update_configuration(
         txhash_contract,
         authority_address,
         contract_addresses,
         min_exit_period_seconds,
         contract_semver,
         network,
         child_block_interval
       )
       when is_binary(txhash_contract) and
              is_binary(authority_address) and is_map(contract_addresses) and is_integer(min_exit_period_seconds) and
              is_binary(contract_semver) and is_binary(network) do
    contract_addresses = Enum.into(contract_addresses, %{}, fn {name, addr} -> {name, String.downcase(addr)} end)
    :ok = Application.put_env(@app, :txhash_contract, String.downcase(txhash_contract), persistent: true)
    :ok = Application.put_env(@app, :authority_addr, String.downcase(authority_address), persistent: true)
    :ok = Application.put_env(@app, :contract_addr, contract_addresses, persistent: true)
    :ok = Application.put_env(@app, :min_exit_period_seconds, min_exit_period_seconds)
    :ok = Application.put_env(@app, :contract_semver, contract_semver)
    :ok = Application.put_env(@app, :network, network)
    :ok = Application.put_env(@app, :child_block_interval, child_block_interval)
  end

  defp update_configuration(_, _, _, _, _, _, _), do: exit(@error)

  defp get_min_exit_period(plasma_framework_contract) do
    signature = "minExitPeriod()"
    {:ok, data} = call(plasma_framework_contract, signature, [])
    %{"min_exit_period" => min_exit_period} = Abi.decode_function(data, signature)
    min_exit_period
  end

  defp get_contract_semver(plasma_framework_contract) do
    signature = "getVersion()"
    {:ok, data} = call(plasma_framework_contract, signature, [])
    %{"version" => version} = Abi.decode_function(data, signature)
    version
  end

  defp get_child_block_interval(plasma_framework_contract) do
    signature = "childBlockInterval()"
    {:ok, data} = rpc().call_contract(plasma_framework_contract, signature, [])
    %{"child_block_interval" => child_block_interval} = Abi.decode_function(data, signature)
    child_block_interval
  end

  defp exit_game_contract_address(plasma_framework_contract, tx_type) do
    signature = "exitGames(uint256)"
    {:ok, data} = call(plasma_framework_contract, signature, [tx_type])
    %{"exit_game_address" => exit_game_address} = Abi.decode_function(data, signature)
    exit_game_address
  end

  defp get_vault(plasma_framework_contract, id) do
    signature = "vaults(uint256)"
    {:ok, data} = call(plasma_framework_contract, "vaults(uint256)", [id])
    %{"vault_address" => vault_address} = Abi.decode_function(data, signature)
    vault_address
  end

  defp call(plasma_framework_contract, signature, args) do
    call(plasma_framework_contract, signature, args, 3)
  end

  defp call(plasma_framework_contract, signature, args, 0) do
    rpc().call_contract(plasma_framework_contract, signature, args)
  end

  defp call(plasma_framework_contract, signature, args, index) do
    case rpc().call_contract(plasma_framework_contract, signature, args) do
      {:ok, _data} = result ->
        result

      {:error, :closed} ->
        Process.sleep(1000)
        call(plasma_framework_contract, signature, args, index - 1)
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

  defp rpc() do
    Application.get_env(:omg_eth, :rpc_api, Rpc)
  end
end
