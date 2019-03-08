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

defmodule OMG.EthTest do
  @moduledoc """
  Thin smoke test of the Ethereum port/adapter.
  The purpose of this test to only prod the marshalling and calling functionalities of the `Eth` wrapper.
  This shouldn't test the contract and should rely as little as possible on the contract logic.
  `OMG.Eth` is intended to be as thin and deprived of own logic as possible, to not require extensive testing.

  Note the excluded moduletag, this test requires an explicit `--include wrappers`
  """

  alias OMG.Eth

  use ExUnitFixtures
  use ExUnit.Case, async: false

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @moduletag :wrappers

  @tag fixtures: [:eth_node]
  test "get_ethereum_height returns integer" do
    assert {:ok, number} = Eth.get_ethereum_height()
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get contract deployment height", %{contract: contract} do
    {:ok, number} = Eth.RootChain.get_root_deployment_height(contract.txhash_contract, contract.contract_addr)
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "no argument call returning single integer", %{contract: contract} do
    assert {:ok, 1000} = Eth.RootChain.get_next_child_block(contract.contract_addr)
  end

  @tag fixtures: [:contract]
  test "single binary argument call returning bool", %{contract: contract} do
    assert {:ok, true} = Eth.RootChain.has_token(@eth, contract.contract_addr)
    assert {:ok, false} = Eth.RootChain.has_token(<<1::160>>, contract.contract_addr)
  end

  @tag fixtures: [:contract]
  test "binary/integer arugments tx and integer argument call returning a binary/integer tuple", %{contract: contract} do
    assert {:ok, _} =
             Eth.RootChain.submit_block(
               <<234::256>>,
               1,
               20_000_000_000,
               contract.authority_addr,
               contract.contract_addr
             )
             |> Eth.DevHelpers.transact_sync!()

    assert {:ok, {child_chain_hash, child_chain_time}} = Eth.RootChain.get_child_chain(1000, contract.contract_addr)
    assert is_binary(child_chain_hash)
    assert byte_size(child_chain_hash) == 32
    assert is_integer(child_chain_time)
  end

  @tag fixtures: [:contract]
  test "gets events with various fields and topics", %{contract: contract} do
    # not using OMG.API.Transaction to not depend on that in omg_eth tests
    zero_in = [0, 0, 0]
    zero_out = [<<0::160>>, <<0::160>>, 0]

    tx =
      [List.duplicate(zero_in, 4), [[contract.authority_addr, @eth, 1]] ++ List.duplicate(zero_out, 3)]
      |> ExRLP.encode()

    {:ok, _} =
      Eth.RootChain.deposit(tx, 1, contract.authority_addr, contract.contract_addr)
      |> Eth.DevHelpers.transact_sync!()

    {:ok, height} = Eth.get_ethereum_height()

    assert {:ok, [%{amount: 1, blknum: 1, owner: contract.authority_addr, currency: @eth, eth_height: height}]} ==
             Eth.RootChain.get_deposits(1, height, contract.contract_addr)
  end
end
