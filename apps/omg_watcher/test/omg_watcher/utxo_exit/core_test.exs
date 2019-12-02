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

defmodule OMG.Watcher.UtxoExit.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.UtxoExit.Core
  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  setup do
    alice = TestHelper.generate_entity()
    %{alice: alice}
  end

  describe "compose_deposit_standard_exit/1" do
    test "creates deposit exit", %{alice: alice} do
      position = Utxo.position(1003, 0, 0)
      encode_utxo = position |> Utxo.Position.encode()

      fake_utxo_db_kv =
        {OMG.InputPointer.Protocol.to_db_key(position),
         Utxo.to_db_value(%Utxo{
           output: %OMG.Output.FungibleMoreVPToken{
             amount: 10,
             currency: @eth,
             owner: alice.addr,
             type_marker: <<1>>
           }
         })}

      assert {:ok,
              %{
                utxo_pos: ^encode_utxo,
                txbytes: txbytes,
                proof: proof
              }} = Core.compose_deposit_standard_exit({:ok, fake_utxo_db_kv})

      assert [%{amount: 10}] = txbytes |> Transaction.decode!() |> Transaction.get_outputs()
      assert byte_size(proof) == 32 * 16
    end

    test "fails to create deposit exit when UTXO missing in DB" do
      assert {:error, :no_deposit_for_given_blknum} = Core.compose_deposit_standard_exit(:not_found)
    end
  end

  describe "compose_utxo_exit/2" do
    test "composes output exit from tx inside a block", %{alice: alice} do
      blknum = 4000
      tx_exit = TestHelper.create_recovered([{1_000, 1, 0, alice}], @eth, [{alice, 10}])
      tx_exit_raw_tx_bytes = Transaction.raw_txbytes(tx_exit)
      position = Utxo.position(blknum, 1, 0)
      encode_utxo = position |> Utxo.Position.encode()

      block =
        [
          TestHelper.create_recovered([{1_000, 2, 0, alice}], @eth, [{alice, 10}]),
          tx_exit,
          TestHelper.create_recovered([{1_000, 3, 0, alice}], @eth, [{alice, 10}])
        ]
        |> Block.hashed_txs_at(blknum)
        |> Block.to_db_value()

      assert {:ok,
              %{
                proof: proof,
                txbytes: ^tx_exit_raw_tx_bytes,
                utxo_pos: ^encode_utxo
              }} = Core.compose_block_standard_exit(block, position)

      # hash byte_size * merkle tree depth
      assert byte_size(proof) == 32 * 16
    end

    test "doesn't find utxo for the output exit, tx position exceeding the block tx count", %{alice: alice} do
      blknum = 4000
      position = Utxo.position(blknum, 1, 0)

      block =
        [TestHelper.create_recovered([{1_000, 1, 0, alice}], @eth, [{alice, 10}])]
        |> Block.hashed_txs_at(blknum)
        |> Block.to_db_value()

      assert {:error, :utxo_not_found} = Core.compose_block_standard_exit(block, position)
    end

    test "doesn't find utxo for the output exit, output position exceeding the output count", %{alice: alice} do
      blknum = 4000
      position = Utxo.position(blknum, 0, 3)

      block =
        [TestHelper.create_recovered([{1_000, 1, 0, alice}], @eth, [{alice, 10}])]
        |> Block.hashed_txs_at(blknum)
        |> Block.to_db_value()

      assert {:error, :utxo_not_found} = Core.compose_block_standard_exit(block, position)
    end

    test "throws when composing output exit, mismatch blknum and utxo pos (should never occur)", %{alice: alice} do
      position = Utxo.position(3000, 0, 0)

      block =
        [TestHelper.create_recovered([{1_000, 1, 0, alice}], @eth, [{alice, 10}])]
        |> Block.hashed_txs_at(4000)
        |> Block.to_db_value()

      assert_raise MatchError, fn -> Core.compose_block_standard_exit(block, position) end
    end
  end
end
