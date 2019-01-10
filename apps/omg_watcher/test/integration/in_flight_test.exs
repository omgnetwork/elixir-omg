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

defmodule OMG.Watcher.Integration.InFlightTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use OMG.API.Integration.Fixtures

  alias OMG.API
  alias OMG.API.Integration.DepositHelper
  alias OMG.Eth
  alias OMG.RPC.Client
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest

  @moduletag :integration

  @eth API.Crypto.zero_address()

  @tag fixtures: [:watcher_sandbox, :child_chain, :alice, :bob]
  test "inputs from in_flight_exit are removed from available utxos", %{alice: alice, bob: bob} do
    {:ok, _} = Eth.DevHelpers.import_unlock_fund(alice)
    deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, 10)

    # alice checks whether she can IFE in case her tx gets lost
    in_flight_exit_info =
      [{deposit_blknum, 0, 0, alice}]
      |> API.TestHelper.create_encoded(@eth, [{alice, 7}, {bob, 3}])
      |> Base.encode16(case: :upper)
      |> IntegrationTest.get_in_flight_exit()

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      Eth.RootChain.in_flight_exit(
        in_flight_exit_info["in_flight_tx"],
        in_flight_exit_info["input_txs"],
        in_flight_exit_info["input_txs_inclusion_proofs"],
        in_flight_exit_info["in_flight_tx_sigs"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(eth_height + 10)

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {bob, 3}])
    assert {:error, {:client_error, %{"code" => "submit:utxo_not_found"}}} = Client.submit(tx)
  end

  @tag fixtures: [:watcher_sandbox, :child_chain, :alice, :bob]
  test "piggyback_in_flight_exit remove utxo from available utxos", %{alice: alice, bob: bob} do
    {:ok, _} = Eth.DevHelpers.import_unlock_fund(alice)
    deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, 10)

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {bob, 3}])
    {:ok, %{blknum: tx_blknum, tx_hash: _tx_hash}} = Client.submit(tx)

    # alice checks whether she can IFE in case her tx gets lost
    in_flight_exit_info =
      tx
      |> Base.encode16(case: :upper)
      |> IntegrationTest.get_in_flight_exit()

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      Eth.RootChain.in_flight_exit(
        in_flight_exit_info["in_flight_tx"],
        in_flight_exit_info["input_txs"],
        in_flight_exit_info["input_txs_inclusion_proofs"],
        in_flight_exit_info["in_flight_tx_sigs"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(eth_height + 10)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      Eth.RootChain.piggyback_in_flight_exit(in_flight_exit_info["in_flight_tx"], 4, alice.addr)
      |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(eth_height + 10)

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {bob, 3}])
    assert {:error, {:client_error, %{"code" => "submit:utxo_not_found"}}} = Client.submit(tx)

    tx = API.TestHelper.create_encoded([{tx_blknum, 0, 0, alice}], @eth, [{alice, 7}])
    assert {:error, {:client_error, %{"code" => "submit:utxo_not_found"}}} = Client.submit(tx)

    tx = API.TestHelper.create_encoded([{tx_blknum, 0, 1, bob}], @eth, [{bob, 3}])
    assert {:ok, _} = Client.submit(tx)
  end
end
