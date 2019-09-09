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

defmodule OMG.Watcher.ExitProcessor.CoreTest do
  @moduledoc """
  Test of the logic of exit processor - various generic tests: starting events, some sanity checks, ife listing
  """
  use OMG.Watcher.ExitProcessor.Case, async: true

  alias OMG.Block
  alias OMG.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core

  require Utxo

  import OMG.Watcher.ExitProcessor.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @late_blknum 10_000

  @utxo_pos1 Utxo.position(2, 0, 0)
  @utxo_pos2 Utxo.position(@late_blknum - 1_000, 0, 1)

  describe "generic sanity checks" do
    test "can start new standard exits one by one or batched", %{processor_empty: empty, alice: alice, bob: bob} do
      standard_exit_tx1 = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
      standard_exit_tx2 = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 10}, {bob, 10}])
      {event1, status1} = se_event_status(standard_exit_tx1, @utxo_pos1)
      {event2, status2} = se_event_status(standard_exit_tx2, @utxo_pos2)
      events = [event1, event2]
      statuses = [status1, status2]

      {state2, _} = Core.new_exits(empty, Enum.slice(events, 0, 1), Enum.slice(statuses, 0, 1))
      {final_state, _} = Core.new_exits(empty, events, statuses)
      assert {^final_state, _} = Core.new_exits(state2, Enum.slice(events, 1, 1), Enum.slice(statuses, 1, 1))
    end

    test "new_exits sanity checks", %{processor_empty: processor} do
      {:error, :unexpected_events} = processor |> Core.new_exits([:anything], [])
      {:error, :unexpected_events} = processor |> Core.new_exits([], [:anything])
    end

    test "can process empty new exits, empty in flight exits",
         %{processor_empty: empty, processor_filled: filled} do
      assert {^empty, []} = Core.new_exits(empty, [], [])
      assert {^empty, []} = Core.new_in_flight_exits(empty, [], [])
      assert {^filled, []} = Core.new_exits(filled, [], [])
      assert {^filled, []} = Core.new_in_flight_exits(filled, [], [])
    end

    test "empty processor returns no exiting utxo positions", %{processor_empty: empty} do
      assert %ExitProcessor.Request{utxos_to_check: []} =
               Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, empty)
    end

    test "in flight exits sanity checks",
         %{processor_empty: state, in_flight_exit_events: events, contract_ife_statuses: statuses} do
      assert {state, []} == Core.new_in_flight_exits(state, [], [])
      assert {:error, :unexpected_events} == Core.new_in_flight_exits(state, Enum.slice(events, 0, 1), [])
      assert {:error, :unexpected_events} == Core.new_in_flight_exits(state, [], Enum.slice(statuses, 0, 1))
    end
  end

  describe "active SE/IFE listing (only IFEs for now)" do
    test "properly processes new in flight exits, returns all of them on request",
         %{processor_empty: processor, in_flight_exit_events: events, contract_ife_statuses: statuses} do
      assert [] == Core.get_active_in_flight_exits(processor)

      {processor, _} = Core.new_in_flight_exits(processor, events, statuses)
      ifes_response = Core.get_active_in_flight_exits(processor)

      assert ifes_response |> Enum.count() == 2
    end

    test "correct format of getting all ifes",
         %{processor_filled: processor, transactions: [tx1, tx2 | _]} do
      assert [
               %{
                 txbytes: OMG.Transaction.Extract.raw_txbytes(tx1),
                 txhash: OMG.Transaction.Extract.raw_txhash(tx1),
                 eth_height: 1,
                 piggybacked_inputs: [],
                 piggybacked_outputs: []
               },
               %{
                 txbytes: OMG.Transaction.Extract.raw_txbytes(tx2),
                 txhash: OMG.Transaction.Extract.raw_txhash(tx2),
                 eth_height: 4,
                 piggybacked_inputs: [],
                 piggybacked_outputs: []
               }
             ] == Core.get_active_in_flight_exits(processor) |> Enum.sort_by(& &1.eth_height)
    end

    test "reports piggybacked inputs/outputs when getting ifes",
         %{processor_empty: processor, transactions: [tx | _]} do
      txhash = OMG.Transaction.Extract.raw_txhash(tx)
      processor = processor |> start_ife_from(tx)
      assert [%{piggybacked_inputs: [], piggybacked_outputs: []}] = Core.get_active_in_flight_exits(processor)

      processor = piggyback_ife_from(processor, txhash, 0)

      assert [%{piggybacked_inputs: [0], piggybacked_outputs: []}] = Core.get_active_in_flight_exits(processor)

      {processor, _} =
        Core.new_piggybacks(processor, [%{tx_hash: txhash, output_index: 4}, %{tx_hash: txhash, output_index: 5}])

      assert [%{piggybacked_inputs: [0], piggybacked_outputs: [0, 1]}] = Core.get_active_in_flight_exits(processor)
    end

    test "challenges don't affect the list of IFEs returned",
         %{processor_filled: processor, transactions: [tx | _], competing_tx: comp} do
      assert Core.get_active_in_flight_exits(processor) |> Enum.count() == 2
      {processor2, _} = Core.new_ife_challenges(processor, [ife_challenge(tx, comp)])
      assert Core.get_active_in_flight_exits(processor2) |> Enum.count() == 2
      # sanity
      assert processor2 != processor
    end
  end

  describe "handling of spent blknums result" do
    test "asks for the right blocks when all are spent correctly" do
      assert [1000] = Core.handle_spent_blknum_result([1000], [@utxo_pos1])
      assert [] = Core.handle_spent_blknum_result([], [])
      assert [2000, 1000] = Core.handle_spent_blknum_result([2000, 1000], [@utxo_pos2, @utxo_pos1])
    end

    test "asks for blocks just once" do
      assert [1000] = Core.handle_spent_blknum_result([1000, 1000], [@utxo_pos2, @utxo_pos1])
    end

    @tag :capture_log
    test "asks for the right blocks if some spends are missing" do
      assert [1000] = Core.handle_spent_blknum_result([:not_found, 1000], [@utxo_pos2, @utxo_pos1])
    end
  end

  describe "finding IFE txs in blocks" do
    test "handles well situation when syncing is in progress", %{processor_filled: state} do
      assert %ExitProcessor.Request{utxos_to_check: [], ife_input_utxos_to_check: []} =
               %ExitProcessor.Request{eth_height_now: 13, blknum_now: 0}
               |> Core.determine_ife_input_utxos_existence_to_get(state)
               |> Core.determine_utxo_existence_to_get(state)
    end

    test "seeks all IFE txs' inputs spends in blocks", %{processor_filled: processor} do
      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5
      }

      # for one piggybacked output, we're asking for its inputs positions to check utxo existence
      request = Core.determine_ife_input_utxos_existence_to_get(request, processor)

      assert [Utxo.position(1, 0, 0), Utxo.position(1, 2, 1), Utxo.position(2, 1, 0), Utxo.position(2, 2, 1)] ==
               request.ife_input_utxos_to_check

      # if it turns out to not exists, we're fetching the spending block
      request =
        request
        |> struct!(%{ife_input_utxo_exists_result: [false, true, true, true]})
        |> Core.determine_ife_spends_to_get(processor)

      assert [Utxo.position(1, 0, 0)] == request.ife_input_spends_to_get
    end

    test "seeks IFE txs in blocks, correctly if IFE inputs duplicate", %{processor_filled: processor, alice: alice} do
      other_tx = TestHelper.create_recovered([{1, 0, 0, alice}], [])
      processor = processor |> start_ife_from(other_tx)

      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5
      }

      # for one piggybacked output, we're asking for its inputs positions to check utxo existence
      request = Core.determine_ife_input_utxos_existence_to_get(request, processor)

      assert [Utxo.position(1, 0, 0), Utxo.position(1, 2, 1), Utxo.position(2, 1, 0), Utxo.position(2, 2, 1)] ==
               request.ife_input_utxos_to_check
    end

    test "seeks IFE txs in blocks only if not already found",
         %{processor_filled: processor, transactions: [tx | _]} do
      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        ife_input_spending_blocks_result: [Block.hashed_txs_at([tx], 3000)]
      }

      processor = processor |> Core.find_ifes_in_blocks(request)
      # for one piggybacked output, we're asking for its inputs positions to check utxo existence
      request = Core.determine_ife_input_utxos_existence_to_get(request, processor)

      assert [Utxo.position(2, 1, 0), Utxo.position(2, 2, 1)] == request.ife_input_utxos_to_check
    end
  end
end
