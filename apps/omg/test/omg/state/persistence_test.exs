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

defmodule OMG.State.PersistenceTest do
  @moduledoc """
  Test focused on the persistence bits of `OMG.State.Core`
  """
  use ExUnitFixtures
  use OMG.DB.RocksDBCase, async: true

  alias OMG.Block
  alias OMG.InputPointer
  alias OMG.State.Core
  alias OMG.State.Transaction
  alias OMG.Utxo

  import OMG.TestHelper

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @interval OMG.Eth.RootChain.get_child_block_interval() |> elem(1)
  @blknum1 @interval

  setup %{db_pid: db_pid} do
    :ok = OMG.DB.initiation_multiupdate(db_pid)
  end

  @tag fixtures: [:state_empty, :alice]
  test "persists_deposits",
       %{alice: alice, db_pid: db_pid, state_empty: state} do
    state
    |> persist_deposit([%{owner: alice.addr, currency: @eth, amount: 20, blknum: 2}], db_pid)
  end

  @tag fixtures: [:alice, :state_empty]
  test "spending produces db updates, that will make the state persist",
       %{alice: alice, db_pid: db_pid, state_empty: state} do
    state
    |> persist_deposit([%{owner: alice.addr, currency: @eth, amount: 20, blknum: 1}], db_pid)
    |> exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 3}]))
    |> persist_form(db_pid)
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "spending produces db updates, that will make the state persist, for all inputs",
       %{alice: alice, db_pid: db_pid, bob: bob, state_empty: state} do
    state
    |> persist_deposit([%{owner: alice.addr, currency: @eth, amount: 20, blknum: 1}], db_pid)
    |> exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}]))
    |> exec(create_recovered([{@blknum1, 0, 0, bob}, {@blknum1, 0, 1, alice}], @eth, [{bob, 10}]))
    |> persist_form(db_pid)

    assert [] = persisted_standard_exitable_utxos(alice, db_pid)
    assert [%{amount: 10, blknum: @blknum1}] = persisted_standard_exitable_utxos(bob, db_pid)
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "utxos are persisted and can be fetched from db",
       %{alice: alice, db_pid: db_pid, state_empty: state} do
    state
    |> persist_deposit([%{owner: alice.addr, currency: @eth, amount: 20, blknum: 1}], db_pid)

    db_key = OMG.InputPointer.Protocol.to_db_key(Utxo.position(1, 0, 0))
    assert {:ok, {^db_key, %{output: %{amount: 20}}}} = OMG.DB.utxo(db_key, db_pid)
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "all utxos get initialized by query result from db",
       %{alice: alice, db_pid: db_pid, bob: bob, state_empty: state} do
    state
    |> persist_deposit([%{owner: alice.addr, currency: @eth, amount: 20, blknum: 1}], db_pid)
    |> persist_deposit([%{owner: bob.addr, currency: @eth, amount: 20, blknum: 2}], db_pid)
    |> exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}]))
    |> persist_form(db_pid)
  end

  @tag fixtures: [:alice, :state_empty]
  test "persists exiting",
       %{alice: alice, db_pid: db_pid, state_empty: state} do
    utxo_pos_exit_1 = Utxo.position(@blknum1, 0, 0)
    utxo_pos_exit_2 = Utxo.position(@blknum1, 0, 1)
    utxo_positions = [utxo_pos_exit_1, utxo_pos_exit_2]

    state
    |> persist_deposit([%{owner: alice.addr, currency: @eth, amount: 20, blknum: 1}], db_pid)
    |> exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 3}]))
    |> persist_form(db_pid)
    |> persist_exit_utxos(utxo_positions, db_pid)
  end

  @tag fixtures: [:alice, :state_empty]
  test "persists piggyback related exits",
       %{alice: alice, db_pid: db_pid, state_empty: state} do
    tx = create_recovered([{1, 0, 0, alice}], @eth, [{alice, 7}, {alice, 3}])

    utxo_pos_exits_in_flight = [%{call_data: %{in_flight_tx: Transaction.raw_txbytes(tx)}}]

    utxo_pos_exits_piggyback = [
      %{tx_hash: Transaction.raw_txhash(tx), output_index: 0, omg_data: %{piggyback_type: :output}}
    ]

    state
    |> persist_deposit([%{owner: alice.addr, currency: @eth, amount: 20, blknum: 1}], db_pid)
    |> exec(tx)
    |> persist_form(db_pid)
    |> persist_exit_utxos(utxo_pos_exits_in_flight, db_pid)
    |> persist_exit_utxos(utxo_pos_exits_piggyback, db_pid)
  end

  @tag fixtures: [:alice, :state_empty]
  test "persists ife related exits",
       %{alice: alice, db_pid: db_pid, state_empty: state} do
    tx = create_signed([{1, 0, 0, alice}], @eth, [{alice, 7}, {alice, 3}])

    utxo_pos_exits_in_flight = [%{call_data: %{in_flight_tx: Transaction.raw_txbytes(tx)}}]

    state
    |> persist_deposit([%{owner: alice.addr, currency: @eth, amount: 20, blknum: 1}], db_pid)
    |> persist_exit_utxos(utxo_pos_exits_in_flight, db_pid)
  end

  @tag fixtures: [:alice, :state_empty]
  test "tx with zero outputs will not be written to DB, but other stuff will!",
       %{alice: alice, db_pid: db_pid, state_empty: state} do
    state
    |> persist_deposit([%{owner: alice.addr, currency: @eth, amount: 20, blknum: 1}], db_pid)
    |> exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 0}]))
    |> persist_form(db_pid)
  end

  @tag fixtures: [:alice, :state_empty]
  test "blocks and spends are persisted",
       %{alice: alice, db_pid: db_pid, state_empty: state} do
    tx = create_recovered([{1, 0, 0, alice}], @eth, [{alice, 3}])

    state
    |> persist_deposit([%{owner: alice.addr, currency: @eth, amount: 20, blknum: 1}], db_pid)
    |> exec(tx)
    |> persist_form(db_pid)

    assert {:ok, [hash]} = OMG.DB.block_hashes([@blknum1], db_pid)

    assert {:ok, [db_block]} = OMG.DB.blocks([hash], db_pid)
    %Block{number: @blknum1, transactions: [block_tx], hash: ^hash} = Block.from_db_value(db_block)

    assert {:ok, tx} == Transaction.Recovered.recover_from(block_tx)

    assert {:ok, 1000} ==
             tx |> Transaction.get_inputs() |> hd() |> InputPointer.Protocol.to_db_key() |> OMG.DB.spent_blknum(db_pid)
  end

  # mimics `&OMG.State.init/1`
  defp state_from(db_pid) do
    {:ok, height_query_result} = OMG.DB.get_single_value(:child_top_block_number, db_pid)
    {:ok, utxos_query_result} = OMG.DB.utxos(db_pid)

    {:ok, state} = Core.extract_initial_state(height_query_result, @interval)
    Core.with_utxos(state, utxos_query_result)
  end

  defp persist_deposit(state, deposits, db_pid) do
    {:ok, {_, db_updates}, state} = Core.deposit(deposits, state)
    persist_common(state, db_updates, db_pid)
  end

  defp persist_form(state, db_pid) do
    {:ok, {_, _, db_updates}, state} = Core.form_block(@interval, state)
    persist_common(state, db_updates, db_pid)
  end

  defp persist_exit_utxos(state, utxo_positions, db_pid) do
    assert {:ok, {db_updates, _}, state} = utxo_positions |> Core.exit_utxos(state)
    persist_common(state, db_updates, db_pid)
  end

  defp exec(state, tx) do
    assert {:ok, _, state} = Core.exec(state, tx, :no_fees_required)
    state
  end

  defp persisted_standard_exitable_utxos(address, db_pid) do
    {:ok, utxos_query_result} = OMG.DB.utxos(db_pid)
    Core.standard_exitable_utxos(utxos_query_result, address.addr)
  end

  defp persist_common(state, db_updates, db_pid) do
    assert :ok = OMG.DB.multi_update(db_updates, db_pid)
    assert state == state_from(db_pid)
    state
  end
end
