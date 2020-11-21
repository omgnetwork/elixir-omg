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
  alias Support.DevHelper
  alias Support.DevNode
  alias Support.RootChainHelper
  alias Support.SnapshotContracts

  @test_eth_vault_id 1
  @test_erc20_vault_id 2

  deffixture eth_node do
    case System.get_env("DOCKER_GETH") do
      nil ->
        if Application.get_env(:omg_eth, :run_test_eth_dev_node, true) do
          {:ok, {geth_pid, _container_id}} = DevNode.start()

          on_exit(fn -> GenServer.stop(geth_pid) end)
        end

        :ok

      _ ->
        :ok
    end
  end

  deffixture contract(eth_node) do
    :ok = eth_node

    {:ok, true} =
      Ethereumex.HttpClient.request("personal_unlockAccount", ["0x6de4b3b9c28e9c3e84c2b2d3a875c947a84de68d", "", 0], [])

    add_exit_queue = RootChainHelper.add_exit_queue(@test_eth_vault_id, "0x0000000000000000000000000000000000000000")

    {:ok, %{"status" => _}} = Support.DevHelper.transact_sync!(add_exit_queue)

    :ok
  end

  deffixture token(contract) do
    :ok = contract
    contracts = SnapshotContracts.parse_contracts()
    token_addr = contracts["CONTRACT_ERC20_MINTABLE"]

    # ensuring that the root chain contract handles token_addr
    {:ok, _} = has_exit_queue(@test_erc20_vault_id, token_addr)
    {:ok, _} = DevHelper.transact_sync!(RootChainHelper.add_exit_queue(@test_erc20_vault_id, token_addr))
    {:ok, true} = has_exit_queue(@test_erc20_vault_id, token_addr)

    token_addr
  end

  defp has_exit_queue(vault_id, token) do
    plasma_framework = Configuration.contracts().plasma_framework
    token = Encoding.from_hex(token)
    call_contract(plasma_framework, "hasExitQueue(uint256,address)", [vault_id, token], [:bool])
  end

  defp call_contract(contract, signature, args, return_types) do
    data = ABI.encode(signature, args)
    {:ok, return} = Ethereumex.HttpClient.eth_call(%{from: contract, to: contract, data: Encoding.to_hex(data)})
    decode_answer(return, return_types)
  end

  defp decode_answer(enc_return, return_types) do
    single_return =
      enc_return
      |> Encoding.from_hex()
      |> ABI.TypeDecoder.decode(return_types)
      |> hd()

    {:ok, single_return}
  end
end
