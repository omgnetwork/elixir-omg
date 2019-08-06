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

  alias OMG.Eth
  alias OMG.Eth.Encoding

  deffixture eth_node do
    {:ok, exit_fn} = Eth.DevNode.start()
    on_exit(exit_fn)
    :ok
  end

  deffixture contract(eth_node) do
    :ok = eth_node

    %{} = Eth.DevHelpers.prepare_env!(root_path: Application.fetch_env!(:omg_eth, :umbrella_root_dir))
  end

  deffixture token(root_chain_contract_config) do
    :ok = root_chain_contract_config

    root_path = Application.fetch_env!(:omg_eth, :umbrella_root_dir)
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()

    {:ok, _, token_addr} = Eth.Deployer.create_new(OMG.Eth.Token, root_path, Encoding.from_hex(addr))

    # ensuring that the root chain contract handles token_addr
    {:ok, false} = Eth.RootChainHelper.has_token(token_addr)
    {:ok, _} = token_addr |> Eth.RootChainHelper.add_token() |> Eth.DevHelpers.transact_sync!()
    {:ok, true} = Eth.RootChainHelper.has_token(token_addr)

    token_addr
  end

  deffixture root_chain_contract_config(contract) do
    Application.put_env(:omg_eth, :contract_addr, Encoding.to_hex(contract.contract_addr), persistent: true)
    Application.put_env(:omg_eth, :authority_addr, Encoding.to_hex(contract.authority_addr), persistent: true)
    Application.put_env(:omg_eth, :txhash_contract, Encoding.to_hex(contract.txhash_contract), persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omg_eth)

    on_exit(fn ->
      Application.put_env(:omg_eth, :contract_addr, nil)
      Application.put_env(:omg_eth, :authority_addr, nil)
      Application.put_env(:omg_eth, :txhash_contract, nil)

      started_apps
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end
end
