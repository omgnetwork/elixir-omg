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

defmodule OMG.Watcher.ExitProcessor.FinalizationsTest do
  @moduledoc """
  Test of the logic of exit processor - finalizing various flavors of exits and handling finalization validity
  """
  use OMG.Watcher.ExitProcessor.Case, async: true

  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor.Core

  require Utxo

  import OMG.Watcher.ExitProcessor.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @utxo_pos1 Utxo.position(2_000, 0, 0)
  @exit_id 1

  describe "sanity checks" do
    test "can process empty finalizations", %{processor_empty: empty, processor_filled: filled} do
      assert {^empty, [], []} = Core.finalize_exits(empty, {[], []})
      assert {^filled, [], []} = Core.finalize_exits(filled, {[], []})
      assert {:ok, %{}} = Core.prepare_utxo_exits_for_in_flight_exit_finalizations(empty, [])
      assert {:ok, %{}} = Core.prepare_utxo_exits_for_in_flight_exit_finalizations(filled, [])
      assert {:ok, ^empty, []} = Core.finalize_in_flight_exits(empty, [], %{})
      assert {:ok, ^filled, []} = Core.finalize_in_flight_exits(filled, [], %{})
    end
  end

  describe "determining utxos that are exited by finalization" do
    test "returns utxos that should be spent when exit finalizes",
         %{processor_empty: processor, transactions: [tx1 | [tx2 | _]]} do
      ife_id1 = 1
      ife_id2 = 2
      tx_hash1 = Transaction.raw_txhash(tx1)
      tx_hash2 = Transaction.raw_txhash(tx2)

      processor =
        processor
        |> start_ife_from(tx1, status: {1, ife_id1})
        |> start_ife_from(tx2, status: {1, ife_id2})
        |> piggyback_ife_from(tx_hash1, 0)
        |> piggyback_ife_from(tx_hash1, 1)
        |> piggyback_ife_from(tx_hash2, 4)
        |> piggyback_ife_from(tx_hash2, 5)

      finalizations = [%{in_flight_exit_id: ife_id1, output_index: 0}, %{in_flight_exit_id: ife_id2, output_index: 4}]

      assert {:ok, %{}} = Core.prepare_utxo_exits_for_in_flight_exit_finalizations(processor, [])

      ife_id1 = <<ife_id1::192>>
      ife_id2 = <<ife_id2::192>>

      tx1_first_input = tx1 |> Transaction.get_inputs() |> hd()
      ife1_exits = {[tx1_first_input], []}
      ife2_exits = {[], [%{tx_hash: tx_hash2, output_index: 4}]}

      assert {:ok, %{^ife_id1 => ^ife1_exits, ^ife_id2 => ^ife2_exits}} =
               Core.prepare_utxo_exits_for_in_flight_exit_finalizations(processor, finalizations)
    end

    test "fails when unknown in-flight exit is being finalized", %{processor_empty: processor} do
      finalization = %{in_flight_exit_id: @exit_id, output_index: 1}

      {:unknown_in_flight_exit, unknown_exits} =
        Core.prepare_utxo_exits_for_in_flight_exit_finalizations(processor, [finalization])

      assert unknown_exits == MapSet.new([<<@exit_id::192>>])
    end

    test "fails when exiting an output that is not piggybacked",
         %{processor_empty: processor, transactions: [tx | _]} do
      tx_hash = Transaction.raw_txhash(tx)
      ife_id = 123

      processor =
        processor
        |> start_ife_from(tx, status: {1, ife_id})
        |> piggyback_ife_from(tx_hash, 1)

      finalization1 = %{in_flight_exit_id: ife_id, output_index: 1}
      finalization2 = %{in_flight_exit_id: ife_id, output_index: 2}

      expected_unknown_piggybacks = [%{in_flight_exit_id: <<ife_id::192>>, output_index: 2}]

      {:unknown_piggybacks, ^expected_unknown_piggybacks} =
        Core.prepare_utxo_exits_for_in_flight_exit_finalizations(processor, [finalization1, finalization2])
    end
  end

  describe "in-flight exit finalization" do
    test "exits piggybacked transaction inputs",
         %{processor_empty: processor, transactions: [tx | _]} do
      ife_id = 123
      tx_hash = Transaction.raw_txhash(tx)

      processor =
        processor
        |> start_ife_from(tx, status: {1, ife_id})
        |> piggyback_ife_from(tx_hash, 0)
        |> piggyback_ife_from(tx_hash, 1)

      assert {:ok, processor, [{:put, :in_flight_exit_info, _}]} =
               Core.finalize_in_flight_exits(processor, [%{in_flight_exit_id: ife_id, output_index: 0}], %{})

      assert {:ok, _, [{:put, :in_flight_exit_info, _}]} =
               Core.finalize_in_flight_exits(processor, [%{in_flight_exit_id: ife_id, output_index: 1}], %{})
    end

    test "exits piggybacked transaction outputs",
         %{processor_empty: processor, transactions: [tx | _]} do
      ife_id = 123
      tx_hash = Transaction.raw_txhash(tx)

      processor =
        processor
        |> start_ife_from(tx, status: {1, ife_id})
        |> piggyback_ife_from(tx_hash, 4)
        |> piggyback_ife_from(tx_hash, 5)

      assert {:ok, _, [{:put, :in_flight_exit_info, _}]} =
               Core.finalize_in_flight_exits(
                 processor,
                 [
                   %{in_flight_exit_id: ife_id, output_index: 5},
                   %{in_flight_exit_id: ife_id, output_index: 4}
                 ],
                 %{}
               )
    end

    test "deactivates in-flight exit after all piggybacked outputs are finalized",
         %{processor_empty: processor, transactions: [tx | _]} do
      ife_id = 123
      tx_hash = Transaction.raw_txhash(tx)

      processor =
        processor
        |> start_ife_from(tx, status: {1, ife_id})
        |> piggyback_ife_from(tx_hash, 1)
        |> piggyback_ife_from(tx_hash, 2)

      {:ok, processor, _} =
        Core.finalize_in_flight_exits(processor, [%{in_flight_exit_id: ife_id, output_index: 1}], %{})

      [_] = Core.get_active_in_flight_exits(processor)

      {:ok, processor, _} =
        Core.finalize_in_flight_exits(processor, [%{in_flight_exit_id: ife_id, output_index: 2}], %{})

      assert [] == Core.get_active_in_flight_exits(processor)
    end

    test "finalizing multiple times does not change state or produce database updates",
         %{processor_empty: processor, transactions: [tx | _]} do
      ife_id = 123
      tx_hash = Transaction.raw_txhash(tx)

      processor =
        processor
        |> start_ife_from(tx, status: {1, ife_id})
        |> piggyback_ife_from(tx_hash, 1)

      finalization = %{in_flight_exit_id: ife_id, output_index: 1}
      {:ok, processor, _} = Core.finalize_in_flight_exits(processor, [finalization], %{})
      {:ok, ^processor, []} = Core.finalize_in_flight_exits(processor, [finalization], %{})
    end

    test "finalizing perserve in flights exits that are not being finalized",
         %{processor_empty: processor, transactions: [tx1, tx2]} do
      ife_id1 = 123
      tx_hash1 = Transaction.raw_txhash(tx1)
      ife_id2 = 124
      tx_hash2 = Transaction.raw_txhash(tx2)

      processor =
        processor
        |> start_ife_from(tx1, status: {1, ife_id1})
        |> start_ife_from(tx2, status: {1, ife_id2})
        |> piggyback_ife_from(tx_hash1, 1)

      finalization = %{in_flight_exit_id: ife_id1, output_index: 1}
      {:ok, processor, _} = Core.finalize_in_flight_exits(processor, [finalization], %{})
      [%{txhash: ^tx_hash2}] = Core.get_active_in_flight_exits(processor)
    end

    test "fails when unknown in-flight exit is being finalized", %{processor_empty: processor} do
      finalization = %{in_flight_exit_id: @exit_id, output_index: 1}

      {:unknown_in_flight_exit, unknown_exits} = Core.finalize_in_flight_exits(processor, [finalization], %{})
      assert unknown_exits == MapSet.new([<<@exit_id::192>>])
    end

    test "fails when exiting an output that is not piggybacked",
         %{processor_empty: processor, transactions: [tx | _]} do
      tx_hash = Transaction.raw_txhash(tx)
      ife_id = 123

      processor =
        processor
        |> start_ife_from(tx, status: {1, ife_id})
        |> piggyback_ife_from(tx_hash, 1)

      finalization1 = %{in_flight_exit_id: ife_id, output_index: 1}
      finalization2 = %{in_flight_exit_id: ife_id, output_index: 2}

      expected_unknown_piggybacks = [%{in_flight_exit_id: <<ife_id::192>>, output_index: 2}]

      {:unknown_piggybacks, ^expected_unknown_piggybacks} =
        Core.finalize_in_flight_exits(processor, [finalization1, finalization2], %{})
    end
  end

  describe "finalization Watcher events" do
    test "emits exit events when finalizing valid exits",
         %{processor_empty: processor, alice: %{addr: alice_addr} = alice} do
      standard_exit_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
      processor = processor |> start_se_from(standard_exit_tx, @utxo_pos1)

      assert {_, [%{exit_finalized: %{amount: 10, currency: @eth, owner: ^alice_addr, utxo_pos: @utxo_pos1}}], _} =
               Core.finalize_exits(processor, {[@utxo_pos1], []})
    end

    test "doesn't emit exit events when finalizing invalid exits",
         %{processor_empty: processor, alice: alice} do
      standard_exit_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
      processor = processor |> start_se_from(standard_exit_tx, @utxo_pos1)
      assert {_, [], _} = Core.finalize_exits(processor, {[], [@utxo_pos1]})
    end
  end
end
