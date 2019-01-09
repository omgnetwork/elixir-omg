# Copyright 2018 OmiseGO Pte Ltd
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

  import Eth.Encoding

  deffixture geth do
    {:ok, exit_fn} = Eth.DevGeth.start()
    on_exit(exit_fn)
    :ok
  end

  deffixture contract(geth) do
    :ok = geth

    Eth.DevHelpers.prepare_env!(root_path: "../../")
  end

  deffixture token(root_chain_contract_config) do
    :ok = root_chain_contract_config

    root_path = "../../"
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()

    {:ok, _, token_addr} = Eth.Deployer.create_new(OMG.Eth.Token, root_path, from_hex(addr))

    # ensuring that the root chain contract handles token_addr
    {:ok, false} = Eth.RootChain.has_token(token_addr)
    {:ok, _} = token_addr |> Eth.RootChain.add_token() |> Eth.DevHelpers.transact_sync!()
    {:ok, true} = Eth.RootChain.has_token(token_addr)

    token_addr
  end

  deffixture root_chain_contract_config(contract) do
    Application.put_env(:omg_eth, :contract_addr, to_hex(contract.contract_addr), persistent: true)
    Application.put_env(:omg_eth, :authority_addr, to_hex(contract.authority_addr), persistent: true)
    Application.put_env(:omg_eth, :txhash_contract, to_hex(contract.txhash_contract), persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omg_eth)

    on_exit(fn ->
      Application.put_env(:omg_eth, :contract_addr, "0x0")
      Application.put_env(:omg_eth, :authority_addr, "0x0")
      Application.put_env(:omg_eth, :txhash_contract, "0x0")

      started_apps
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end
end
