# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule Itest.PlasmaFramework do
  @moduledoc """
  Used to pull information out of the main root chain contract PlasmaFramework.sol
  """

  alias Itest.Transactions.Currency
  alias Itest.Transactions.Encoding

  def address() do
    contracts = parse_contracts()

    contracts["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"]
    |> EIP55.encode()
    |> elem(1)
  end

  @ether_vault_id 1
  @erc20_vault_id 2

  def vault_id(currency) do
    ether = Currency.ether()
    erc20 = Currency.erc20()

    case currency do
      ^ether -> @ether_vault_id
      ^erc20 -> @erc20_vault_id
    end
  end

  def vault(currency) do
    ether = Currency.ether()
    erc20 = Currency.erc20()

    case currency do
      ^ether -> get_vault(@ether_vault_id)
      ^erc20 -> get_vault(@erc20_vault_id)
    end
  end

  def exit_game_contract_address(tx_type) do
    data = ABI.encode("exitGames(uint256)", [tx_type])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: address(), data: Encoding.to_hex(data)})

    result
    |> Encoding.to_binary()
    |> ABI.TypeDecoder.decode([:address])
    |> hd()
    |> Encoding.to_hex()
  end

  defp get_vault(id) do
    data = ABI.encode("vaults(uint256)", [id])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: address(), data: Encoding.to_hex(data)})

    result
    |> Encoding.to_binary()
    |> ABI.TypeDecoder.decode([:address])
    |> hd()
    |> Encoding.to_hex()
    |> EIP55.encode()
    |> elem(1)
  end

  # taken from the plasma-contracts deployment snapshot
  # this parsing occurs in several places around the codebase
  defp parse_contracts() do
    local_umbrella_path = Path.join([File.cwd!(), "../../../../", "localchain_contract_addresses.env"])

    contract_addreses_path =
      case File.exists?(local_umbrella_path) do
        true ->
          local_umbrella_path

        _ ->
          # CI/CD
          Path.join([File.cwd!(), "localchain_contract_addresses.env"])
      end

    contract_addreses_path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> List.flatten()
    |> Enum.reduce(%{}, fn line, acc ->
      [key, value] = String.split(line, "=")
      Map.put(acc, key, value)
    end)
  end
end
