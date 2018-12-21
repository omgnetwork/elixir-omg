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

defmodule OMG.Watcher.Integration.WatcherApiTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use OMG.API.Integration.Fixtures
  use Plug.Test

  alias OMG.API
  alias OMG.API.State.Transaction
  alias OMG.Eth
  alias OMG.RPC.Client
  alias OMG.Watcher.TestHelper
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest

  require Utxo

  import Eth.Encoding

  @timeout 40_000
  @eth Crypto.zero_address()
  @eth_hex String.duplicate("00", 20)
  @in_flight_exit_bond 31_415_926_535

  @moduletag :integration

  @tag fixtures: [:watcher_sandbox, :alice, :child_chain, :token, :alice_deposits]
  test "in-flight exit data retruned by watcher http API produces a valid in-flight exit",
       %{alice: alice, alice_deposits: {deposit_blknum, _}} do
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 5}])
    {:ok, %{blknum: blknum, tx_index: txindex}} = Client.submit(tx)

    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    %Transaction.Signed{raw_tx: raw_in_flight_tx} =
      in_flight_tx =
      API.TestHelper.create_signed([{blknum, txindex, 0, alice}, {blknum, txindex, 1, alice}], @eth, [{alice, 10}])

    encoded_in_flight_tx = Transaction.Signed.encode(in_flight_tx)

    %{
      "in_flight_tx" => in_flight_tx,
      "in_flight_tx_sigs" => in_flight_tx_sigs,
      "input_txs" => input_txs,
      "input_txs_inclusion_proofs" => input_txs_inclusion_proofs
    } = TestHelper.get_in_flight_exit(encoded_in_flight_tx)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      OMG.Eth.RootChain.in_flight_exit(
        in_flight_tx,
        input_txs,
        input_txs_inclusion_proofs,
        in_flight_tx_sigs,
        alice.addr,
        @in_flight_exit_bond
      )
      |> Eth.DevHelpers.transact_sync!()

    in_flight_tx_hash = Transaction.hash(raw_in_flight_tx)
    alice_address = alice.addr

    assert {:ok, [%{initiator: ^alice_address, txhash: ^in_flight_tx_hash}]} =
             OMG.Eth.RootChain.get_in_flight_exits(0, eth_height)
  end
end
