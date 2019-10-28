# Copyright 2019 OmiseGO Pte Ltd
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

  alias OMG.Eth.Encoding
  alias OMG.Eth.RootChain
  alias Support.Deployer
  alias Support.DevHelper
  alias Support.DevNode
  alias Support.RootChainHelper

  @test_erc20_vault_id 2

  deffixture eth_node do
    {:ok, exit_fn} = DevNode.start()
    on_exit(exit_fn)
    :ok
  end

  deffixture contract(eth_node) do
    :ok = eth_node

    contract = DevHelper.prepare_env!(root_path: Application.fetch_env!(:omg_eth, :umbrella_root_dir))
    contract
  end

  deffixture token(root_chain_contract_config) do
    :ok = root_chain_contract_config

    root_path = Application.fetch_env!(:omg_eth, :umbrella_root_dir)
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()

    {:ok, _, token_addr} = Deployer.create_new("ERC20Mintable", root_path, Encoding.from_hex(addr), [])

    # ensuring that the root chain contract handles token_addr
    {:ok, false} = RootChainHelper.has_exit_queue(@test_erc20_vault_id, token_addr)
    {:ok, _} = RootChainHelper.add_exit_queue(@test_erc20_vault_id, token_addr) |> DevHelper.transact_sync!()
    {:ok, true} = RootChainHelper.has_exit_queue(@test_erc20_vault_id, token_addr)

    token_addr
  end

  deffixture root_chain_contract_config(contract) do
    contract_addr = RootChain.contract_map_to_hex(contract.contract_addr)
    Application.put_env(:omg_eth, :contract_addr, contract_addr, persistent: true)
    Application.put_env(:omg_eth, :authority_addr, Encoding.to_hex(contract.authority_addr), persistent: true)
    Application.put_env(:omg_eth, :txhash_contract, Encoding.to_hex(contract.txhash_contract), persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omg_eth)

    on_exit(fn ->
      # reverting to the original values from `omg_eth/config/test.exs`
      Application.put_env(:omg_eth, :contract_addr, %{plasma_framework: "0x0000000000000000000000000000000000000001"})
      Application.put_env(:omg_eth, :authority_addr, nil)
      Application.put_env(:omg_eth, :txhash_contract, nil)

      started_apps
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end
end
