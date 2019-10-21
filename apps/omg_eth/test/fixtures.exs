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

  alias OMG.Eth.Deployer
  alias OMG.Eth.Encoding
  alias OMG.Eth.RootChain
  alias OMG.Eth.RootChainHelper
  alias OMG.Eth.Test.Support.DevHelper
  alias OMG.Eth.Test.Support.DevNode

  deffixture eth_node do
    {:ok, exit_fn} = DevNode.start()
    on_exit(exit_fn)
    # NOTE: The request_body will send an incrementing request "id" in each body.
    #
    # see: https://github.com/mana-ethereum/ethereumex/blob/649075208d2af663b9aac262b153021e960c4df8/lib/ethereumex/client/base_client.ex#L503
    #
    # The problem is the fixtures would send a first request out(this request). When you remove the fixtures,
    # Ethereumex thinks we are sending the first request, missing the matching cassettes by request_body.
    # So, we reset the counter so the cassettes can reply correctly without the fixtures:
    :ets.insert(:rpc_requests_counter, {:rpc_counter, 0})
    :ok
  end

  deffixture contract(eth_node) do
    :ok = eth_node

    contract = DevHelper.prepare_env!(root_path: Application.fetch_env!(:omg_eth, :umbrella_root_dir))
    :ets.insert(:rpc_requests_counter, {:rpc_counter, 0})
    contract
  end

  deffixture token(root_chain_contract_config) do
    :ok = root_chain_contract_config

    root_path = Application.fetch_env!(:omg_eth, :umbrella_root_dir)
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()

    {:ok, _, token_addr} = Deployer.create_new("ERC20Mintable", root_path, Encoding.from_hex(addr), [])

    # ensuring that the root chain contract handles token_addr
    {:ok, false} = RootChainHelper.has_token(token_addr)
    {:ok, _} = token_addr |> RootChainHelper.add_token() |> DevHelper.transact_sync!()
    {:ok, true} = RootChainHelper.has_token(token_addr)
    :ets.insert(:rpc_requests_counter, {:rpc_counter, 0})
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

    :ets.insert(:rpc_requests_counter, {:rpc_counter, 0})
    :ok
  end
end
