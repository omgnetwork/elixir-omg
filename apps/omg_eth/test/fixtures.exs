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
  alias OMG.Eth.ReleaseTasks.SetContract
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

    contracts = SnapshotContracts.parse_contracts()

    {:ok, true} =
      Ethereumex.HttpClient.request("personal_unlockAccount", ["0x6de4b3b9c28e9c3e84c2b2d3a875c947a84de68d", "", 0], [])

    :ok = System.put_env("ETHEREUM_NETWORK", "LOCALCHAIN")
    :ok = System.put_env("TXHASH_CONTRACT", contracts["TXHASH_CONTRACT"])
    :ok = System.put_env("AUTHORITY_ADDRESS", contracts["AUTHORITY_ADDRESS"])
    :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", contracts["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"])
    SetContract.init([])

    add_exit_queue = RootChainHelper.add_exit_queue(@test_eth_vault_id, "0x0000000000000000000000000000000000000000")

    {:ok, %{"status" => "0x1"}} = Support.DevHelper.transact_sync!(add_exit_queue)

    :ok
  end

  deffixture token(root_chain_contract_config) do
    :ok = root_chain_contract_config
    contracts = SnapshotContracts.parse_contracts()
    token_addr = contracts["CONTRACT_ERC20_MINTABLE"]

    # ensuring that the root chain contract handles token_addr
    {:ok, false} = has_exit_queue(@test_erc20_vault_id, token_addr)
    {:ok, _} = DevHelper.transact_sync!(RootChainHelper.add_exit_queue(@test_erc20_vault_id, token_addr))
    {:ok, true} = has_exit_queue(@test_erc20_vault_id, token_addr)

    token_addr
  end

  deffixture root_chain_contract_config(contract) do
    _ = contract

    # {:ok, started_apps} = Application.ensure_all_started(:omg_eth)

    on_exit(fn ->
      # reverting to the original values from `omg_eth/config/test.exs`
      Application.put_env(:omg_eth, :contract_addr, %{plasma_framework: "0x0000000000000000000000000000000000000001"})
      Application.put_env(:omg_eth, :authority_addr, nil)
      Application.put_env(:omg_eth, :txhash_contract, nil)

      # started_apps
      # |> Enum.reverse()
      # |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end

  defp has_exit_queue(vault_id, token) do
    plasma_framework = Configuration.contracts().plasma_framework
    token = Encoding.from_hex(token)
    call_contract(plasma_framework, "hasExitQueue(uint256,address)", [vault_id, token], [:bool])
  end

  defp call_contract(contract, signature, args, return_types) do
    data = ABI.encode(signature, args)
    {:ok, return} = Ethereumex.HttpClient.eth_call(%{to: contract, data: Encoding.to_hex(data)})
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
