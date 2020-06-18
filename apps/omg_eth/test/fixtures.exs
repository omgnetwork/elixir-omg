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

defmodule OMG.Eth.Fixtures do
  @moduledoc """
  Contains fixtures for tests that require geth and contract
  """
  use ExUnitFixtures.FixtureModule

  alias OMG.Eth.Configuration
  alias OMG.Eth.Encoding
  alias OMG.Eth.RootChain.Abi, as: RootChainABI
  alias OMG.WireFormatTypes
  alias Support.DevHelper
  alias Support.DevNode
  alias Support.RootChainHelper
  alias Support.SnapshotContracts

  @test_eth_vault_id 1
  @test_erc20_vault_id 2

  deffixture eth_node do
    if Application.get_env(:omg_eth, :run_test_eth_dev_node, true) do
      {:ok, exit_fn} = DevNode.start()

      on_exit(exit_fn)
    end

    :ok
  end

  deffixture contract(eth_node) do
    :ok = eth_node

    :ok = setup_exit_games()

    {:ok, true} =
      Ethereumex.HttpClient.request("personal_unlockAccount", ["0x6de4b3b9c28e9c3e84c2b2d3a875c947a84de68d", "", 0], [])

    add_exit_queue = RootChainHelper.add_exit_queue(@test_eth_vault_id, "0x0000000000000000000000000000000000000000")

    {:ok, %{"status" => "0x1"}} = Support.DevHelper.transact_sync!(add_exit_queue)

    :ok
  end

  deffixture token(contract) do
    :ok = contract
    contracts = SnapshotContracts.parse_contracts()
    token_addr = contracts["CONTRACT_ERC20_MINTABLE"]

    # ensuring that the root chain contract handles token_addr
    {:ok, false} = has_exit_queue(@test_erc20_vault_id, token_addr)
    {:ok, _} = DevHelper.transact_sync!(RootChainHelper.add_exit_queue(@test_erc20_vault_id, token_addr))
    {:ok, true} = has_exit_queue(@test_erc20_vault_id, token_addr)

    token_addr
  end

  # inject the exit games into :omg_eth
  # test fixture does not rely on the release task so it would need this setup
  defp setup_exit_games() do
    contracts = SnapshotContracts.parse_contracts()
    plasma_framework = contracts["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"]

    exit_games =
      Enum.into(WireFormatTypes.exit_game_tx_types(), %{}, fn type ->
        {type,
         plasma_framework
         |> exit_game_contract_address(WireFormatTypes.tx_type_for(type))
         |> Encoding.to_hex()}
      end)

    Application.put_env(:omg_eth, :exit_games, exit_games)
  end

  defp has_exit_queue(vault_id, token) do
    plasma_framework = Configuration.contracts().plasma_framework
    token = Encoding.from_hex(token)
    {:ok, return} = call_contract(plasma_framework, "hasExitQueue(uint256,address)", [vault_id, token])
    decode_answer(return, [:bool])
  end

  defp call_contract(contract, signature, args) do
    data = ABI.encode(signature, args)
    {:ok, return} = Ethereumex.HttpClient.eth_call(%{to: contract, data: Encoding.to_hex(data)})
  end

  defp decode_answer(enc_return, return_types) do
    single_return =
      enc_return
      |> Encoding.from_hex()
      |> ABI.TypeDecoder.decode(return_types)
      |> hd()

    {:ok, single_return}
  end

  defp exit_game_contract_address(plasma_framework_contract, tx_type) do
    signature = "exitGames(uint256)"
    {:ok, data} = call_contract(plasma_framework_contract, signature, [tx_type])
    %{"exit_game_address" => exit_game_address} = RootChainABI.decode_function(data, signature)
    exit_game_address
  end
end
