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

defmodule OMG.Watcher.API.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.Fixtures

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.API.Core
  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  test "getting exit data returns error when there is no deposit" do
    assert {:error, :no_deposit_for_given_blknum} == Core.compose_deposit_exit(nil, Utxo.position(1003, 0, 0))
  end

  @tag fixtures: [:alice]
  test "creating deposit exit", %{alice: alice} do
    position = Utxo.position(1000, 0, 0)
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

  @tag fixtures: [:alice]
  test "compose output exit", %{alice: alice} do
    tx_encode = fn number ->
      TestHelper.create_signed([{1_000, number, 0, alice}], @eth, [{alice, 10}])
      |> Transaction.Signed.encode()
    end

    tx_exit = tx_encode.(30)
    tx_exit_raw_tx_bytes = Transaction.Signed.decode(tx_exit) |> elem(1) |> Transaction.raw_txbytes()

    position = Utxo.position(3, 0, 1)
    encode_utxo = position |> Utxo.Position.encode()

    assert {:ok,
            %{
              proof: _proof,
              sigs: _sig,
              txbytes: ^tx_exit_raw_tx_bytes,
              utxo_pos: ^encode_utxo
            }} =
             Core.compose_output_exit(
               [
                 %{txindex: 2, txbytes: tx_encode.(20)},
                 %{txindex: 1, txbytes: tx_encode.(10)},
                 %{txindex: 0, txbytes: tx_exit},
                 %{txindex: 3, txbytes: tx_encode.(0)}
               ],
               position
             )
  end

  test "getting exit data returns error when there is no utxo" do
    assert {:error, :utxo_not_found} == Core.compose_output_exit([], Utxo.position(1_000, 1, 2))
  end

  test "return utxo when in blknum in utxos map" do
    assert 7 ==
             Core.get_deposit_utxo(
               {:ok, Map.new(Enum.map(1..20, fn a -> {{a, 0, 0}, a} end))},
               Utxo.position(7, 0, 0)
             )
  end

  test "return nil when in blknum not in utxos map" do
    assert nil ==
             Core.get_deposit_utxo(
               {:ok, Map.new(Enum.map(1..20, fn a -> {{a, 0, 0}, a} end))},
               Utxo.position(42, 0, 0)
             )
  end
end
