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

  test "getting exit data returns error when there is no deposit" do
    assert {:error, :no_deposit_for_given_blknum} == Core.compose_deposit_exit(nil, Utxo.position(1003, 0, 0))
  end

  test "creating deposit exit", %{alice: alice} do
    position = Utxo.position(1003, 0, 0)
    encode_utxo = position |> Utxo.Position.encode()

    assert {:ok,
            %{
              utxo_pos: ^encode_utxo,
              txbytes: _txbytes,
              proof: _proof
            }} =
             Core.compose_deposit_exit(
               %{
                 amount: 10,
                 currency: OMG.Eth.zero_address(),
                 owner: alice.addr
               },
               position
             )
  end

  test "compose output exit", %{alice: alice} do
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
            }} = Core.compose_output_exit(block, position)

    assert byte_size(proof) == 32 * 16
  end

  test "compose output exit, position exceeding the block tx count", %{alice: alice} do
    blknum = 4000
    position = Utxo.position(blknum, 1, 0)

    block =
      [TestHelper.create_recovered([{1_000, 1, 0, alice}], @eth, [{alice, 10}])]
      |> Block.hashed_txs_at(blknum)
      |> Block.to_db_value()

    assert {:error, :utxo_not_found} = Core.compose_output_exit(block, position)
  end

  test "compose output exit, erroneously mismatch blknum and utxo pos (should never occur)", %{alice: alice} do
    position = Utxo.position(3000, 0, 0)

    block =
      [TestHelper.create_recovered([{1_000, 1, 0, alice}], @eth, [{alice, 10}])]
      |> Block.hashed_txs_at(4000)
      |> Block.to_db_value()

    assert_raise MatchError, fn -> Core.compose_output_exit(block, position) end
  end

  test "getting exit data returns error when there is no utxo" do
    block = Block.hashed_txs_at([], 1000) |> Block.to_db_value()

    assert {:error, :utxo_not_found} ==
             Core.compose_output_exit(block, Utxo.position(1_000, 1, 2))
  end

  test "return utxo when in blknum in utxos map", %{alice: %{addr: alice_addr}} do
    assert %{amount: 7, currency: @eth, owner: alice_addr} ==
             Core.get_deposit_utxo(
               {:ok,
                Map.new(Enum.map(1..20, fn a -> {{a, 0, 0}, %{amount: a, currency: @eth, owner: alice_addr}} end))},
               Utxo.position(7, 0, 0)
             )
  end

  test "return nil when in blknum not in utxos map", %{alice: alice} do
    assert nil ==
             Core.get_deposit_utxo(
               {:ok,
                Map.new(Enum.map(1..20, fn a -> {{a, 0, 0}, %{amount: a, currency: @eth, owner: alice.addr}} end))},
               Utxo.position(42, 0, 0)
             )
  end
end
