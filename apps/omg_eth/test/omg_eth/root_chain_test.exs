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

defmodule OMG.RootChainTest do
  alias OMG.Eth
  alias OMG.Eth.Encoding
  alias OMG.Eth.DevHelpers
  alias OMG.Eth.RootChain
  alias OMG.Eth.RootChainHelper

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @moduletag :common

  setup do
    ExVCR.Config.cassette_library_dir("test/fixtures/vcr_cassettes/root_chain")
    :ok
  end

  @tag fixtures: [:contract]
  test "get_root_deployment_height/2 returns current block number", %{contract: contract} do
    {:ok, number} = RootChain.get_root_deployment_height(contract.txhash_contract, contract.contract_addr)
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get_next_child_block/1 returns next blknum to be mined by operator", %{contract: contract} do
    assert {:ok, 1000} = RootChain.get_next_child_block(contract.contract_addr)
  end

  describe "has_token/2" do

    @tag fixtures: [:contract]
    test "returns true  if token exists", %{contract: contract} do
      assert {:ok, true} = RootChainHelper.has_token(@eth, contract.contract_addr)
    end

    @tag fixtures: [:contract]
    test "returns false if no token exists", %{contract: contract} do
      assert {:ok, false} = RootChainHelper.has_token(<<1::160>>, contract.contract_addr)
    end
  end

  @tag fixtures: [:contract]
  test "get_child_chain/2 returns the current block hash and timestamp", %{contract: contract} do
    block = RootChain.submit_block(
             <<234::256>>,
             1,
             20_000_000_000,
             contract.authority_addr,
             contract.contract_addr
           )

    assert {:ok, _} = 
      DevHelpers.transact_sync!(block)

    assert {:ok, {child_chain_hash, child_chain_time}} = 
      RootChain.get_child_chain(1000, contract.contract_addr)

    assert is_binary(child_chain_hash)
    assert byte_size(child_chain_hash) == 32
    assert is_integer(child_chain_time)
  end

  @tag fixtures: [:contract]
  test "get_deposits/3 returns deposit events", %{contract: contract} do
    # not using OMG.ChildChain.Transaction to not depend on that in omg_eth tests
    # payment marker, no inputs, one output, metadata
    tx =
      [<<1>>, [], [[contract.authority_addr, @eth, 1]], <<0::256>>]
      |> ExRLP.encode()

    {:ok, tx_hash} =
      RootChainHelper.deposit(tx, 1, contract.authority_addr, contract.contract_addr)
      |> DevHelpers.transact_sync!()

    {:ok, height} = Eth.get_ethereum_height()

    authority_addr = contract.authority_addr
    root_chain_txhash = Encoding.from_hex(tx_hash["transactionHash"])

    deposits = RootChain.get_deposits(1, height, contract.contract_addr)

    assert {:ok,
            [
              %{
                amount: 1,
                blknum: 1,
                owner: ^authority_addr,
                currency: @eth,
                eth_height: height,
                log_index: 0,
                root_chain_txhash: ^root_chain_txhash
              }
            ]} = deposits
  end
end
