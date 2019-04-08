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

defmodule OMG.Watcher.DB.EthEventTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  alias OMG.Utxo
  alias OMG.Watcher.DB

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "insert deposits: creates deposit event and utxo" do
    owner = <<1::160>>
    expected_hash = DB.EthEvent.generate_unique_key(Utxo.position(1, 0, 0), :deposit)
    DB.EthEvent.insert_deposits!([%{blknum: 1, owner: owner, currency: @eth, amount: 1}])

    [event] = DB.EthEvent.get_all()
    assert %DB.EthEvent{blknum: 1, txindex: 0, event_type: :deposit, hash: ^expected_hash} = event

    utxo = DB.TxOutput.get_by_position(Utxo.position(1, 0, 0))

    assert %DB.TxOutput{
             blknum: 1,
             txindex: 0,
             oindex: 0,
             owner: ^owner,
             currency: @eth,
             amount: 1,
             creating_deposit: ^expected_hash
           } = utxo
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice]
  test "insert deposits: creates deposits and retrieves them by hash", %{alice: alice} do
    :ok =
      DB.EthEvent.insert_deposits!([
        %{blknum: 1, owner: alice.addr, currency: @eth, amount: 1},
        %{blknum: 1000, owner: alice.addr, currency: @eth, amount: 2},
        %{blknum: 2013, owner: alice.addr, currency: @eth, amount: 3}
      ])

    hash1 = DB.EthEvent.generate_unique_key(Utxo.position(1, 0, 0), :deposit)

    assert %DB.EthEvent{blknum: 1, txindex: 0, event_type: :deposit, hash: ^hash1} = DB.EthEvent.get(hash1)

    hash2 = DB.EthEvent.generate_unique_key(Utxo.position(1000, 0, 0), :deposit)

    assert %DB.EthEvent{blknum: 1000, txindex: 0, event_type: :deposit, hash: ^hash2} = DB.EthEvent.get(hash2)

    hash3 = DB.EthEvent.generate_unique_key(Utxo.position(2013, 0, 0), :deposit)

    assert %DB.EthEvent{blknum: 2013, txindex: 0, event_type: :deposit, hash: ^hash3} = DB.EthEvent.get(hash3)

    assert [hash1, hash2, hash3] == DB.TxOutput.get_utxos(alice.addr) |> Enum.map(& &1.creating_deposit)
  end

  @tag fixtures: [:initial_blocks]
  test "insert exits: creates exit event and marks utxo as spent" do
    bobs_deposit_pos = Utxo.position(2, 0, 0)
    bobs_deposit_exit_hash = DB.EthEvent.generate_unique_key(bobs_deposit_pos, :exit)

    alices_utxo_pos = Utxo.position(3000, 1, 1)
    alices_utxo_exit_hash = DB.EthEvent.generate_unique_key(alices_utxo_pos, :exit)

    to_insert = prepare_to_insert([bobs_deposit_pos, alices_utxo_pos])
    :ok = DB.EthEvent.insert_exits!(to_insert)

    assert %DB.EthEvent{blknum: 2, txindex: 0, event_type: :exit, hash: ^bobs_deposit_exit_hash} =
             DB.EthEvent.get(bobs_deposit_exit_hash)

    assert %DB.EthEvent{blknum: 3000, txindex: 1, event_type: :exit, hash: ^alices_utxo_exit_hash} =
             DB.EthEvent.get(alices_utxo_exit_hash)

    assert %DB.TxOutput{amount: 100, spending_tx_oindex: nil, spending_exit: ^bobs_deposit_exit_hash} =
             DB.TxOutput.get_by_position(bobs_deposit_pos)

    assert %DB.TxOutput{amount: 50, spending_tx_oindex: nil, spending_exit: ^alices_utxo_exit_hash} =
             DB.TxOutput.get_by_position(alices_utxo_pos)
  end

  @tag fixtures: [:alice, :initial_blocks]
  test "Writes of deposits and exits are idempotent", %{alice: alice} do
    # try to insert again existing deposit (from initial_blocks)
    assert :ok = DB.EthEvent.insert_deposits!([%{owner: alice.addr, currency: @eth, amount: 333, blknum: 1}])

    to_insert = prepare_to_insert([Utxo.position(1, 0, 0), Utxo.position(1, 0, 0)])

    assert :ok = DB.EthEvent.insert_exits!(to_insert)
  end

  defp prepare_to_insert(positions),
    do: Enum.map(positions, &%{call_data: %{utxo_pos: Utxo.Position.encode(&1)}})
end
