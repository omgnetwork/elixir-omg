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
defmodule Itest.Transactions.Currency do
  @moduledoc false
  import Itest.Poller, only: [wait_on_receipt_confirmed: 1]

  alias Itest.Transactions.Encoding

  @ether <<0::160>>
  @approve_gas 50_000

  #
  # ETH
  #

  def ether(), do: @ether

  def to_wei(ether) when is_binary(ether) do
    ether
    |> String.to_integer()
    |> to_wei()
  end

  def to_wei(ether) when is_integer(ether), do: ether * 1_000_000_000_000_000_000

  #
  # ERC-20
  #

  def erc20() do
    contracts = parse_contracts()
    Encoding.to_binary(contracts["CONTRACT_ERC20_MINTABLE"])
  end

  def mint_erc20(to_addr, amount) do
    {:ok, [faucet | _]} = Ethereumex.HttpClient.eth_accounts()

    data = ABI.encode("mint(address,uint256)", [Encoding.to_binary(to_addr), amount])

    txmap = %{
      from: faucet,
      to: Encoding.to_hex(erc20()),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(80_000)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    wait_on_receipt_confirmed(receipt_hash)
    {:ok, receipt_hash}
  end

  def approve_erc20(owner_address, amount_in_wei, spender_address) do
    data = ABI.encode("approve(address,uint256)", [spender_address, amount_in_wei])

    txmap = %{
      from: owner_address,
      to: Encoding.to_hex(erc20()),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@approve_gas)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)

    wait_on_receipt_confirmed(receipt_hash)
    {:ok, receipt_hash}
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
