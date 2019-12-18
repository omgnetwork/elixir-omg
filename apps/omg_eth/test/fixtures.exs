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
  @eth OMG.Eth.RootChain.eth_pseudo_address()

  deffixture eth_node do
    if Application.get_env(:omg_eth, :run_test_eth_dev_node, true) do
      {:ok, exit_fn} = DevNode.start()
      on_exit(exit_fn)
    end

    :ok
  end

  deffixture contract(eth_node) do
    :ok = eth_node

    contract = %{
      authority_addr: Encoding.from_hex("0xc0f780dfc35075979b0def588d999225b7ecc56f"),
      contract_addr: %{
        erc20_vault: Encoding.from_hex("0x04badc20426bc146453c5b879417b25029fa6c73"),
        eth_vault: Encoding.from_hex("0x0433420dee34412b5bf1e29fbf988ad037cc5db7"),
        payment_exit_game: Encoding.from_hex("0x92ce4d7773c57d96210c46a07b89acf725057f21"),
        plasma_framework: Encoding.from_hex("0xc673e4ffcb8464faff908a6804fe0e635af0ea2f")
      },
      txhash_contract: Encoding.from_hex("0xcd96b40b8324a4e10b421d6dd9796d200c64f7af6799f85262fa8951aed2f10c")
    }

    {:ok, true} =
      Ethereumex.HttpClient.request("personal_unlockAccount", ["0x6de4b3b9c28e9c3e84c2b2d3a875c947a84de68d", "", 0], [])

    add_exit_queue =
      RootChainHelper.add_exit_queue(1, @eth, %{
        plasma_framework: Encoding.from_hex("0xc673e4ffcb8464faff908a6804fe0e635af0ea2f")
      })

    {:ok, _} = Support.DevHelper.transact_sync!(add_exit_queue)
    contract
  end

  deffixture token(root_chain_contract_config) do
    :ok = root_chain_contract_config

    root_path = Application.fetch_env!(:omg_eth, :umbrella_root_dir)
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()

    {:ok, _, token_addr} = "0x32063dba91cf95eb3d58fad9e391ee888878b61c"

    # ensuring that the root chain contract handles token_addr
    {:ok, false} = RootChainHelper.has_exit_queue(@test_erc20_vault_id, token_addr)
    {:ok, _} = DevHelper.transact_sync!(RootChainHelper.add_exit_queue(@test_erc20_vault_id, token_addr))
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
