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

  @doc """
  The contract values can currently come either from ENV variables for deployments in
  - development
  - stagind
  - production
  or, they're manually deployed for local development:
  """
  @impl Provider
  def init(_args) do
    case get_env("ETHEREUM_NETWORK") do
      "RINKEBY" = network -> :ok = apply_settings(network)
      _ -> exit("Rinkeby or not implemented. There's no contracts that the release could point to.")
    end

    :ok
  end

  defp apply_settings(network) do
    txhash_contract = get_env(network <> "_TXHASH_CONTRACT")
    authority_address = get_env(network <> "_AUTHORITY_ADDRESS")
    contract_address = get_env(network <> "_CONTRACT_ADDRESS")
    :ok = Application.put_env(:omg_eth, :txhash_contract, txhash_contract, persistent: true)
    :ok = Application.put_env(:omg_eth, :authority_addr, authority_address, persistent: true)
    :ok = Application.put_env(:omg_eth, :contract_addr, contract_address, persistent: true)
  end

  defp get_env(key), do: validate(System.get_env(key))

  defp validate(value) when is_binary(value), do: value

  defp validate(nil),
    do:
      exit("Set RINKEBY_TXHASH_CONTRACT, RINKEBY_AUTHORITY_ADDRESS and RINKEBY_CONTRACT_ADDRESS environment variables.")
end
