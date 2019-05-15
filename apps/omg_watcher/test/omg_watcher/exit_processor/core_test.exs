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

defmodule OMG.Watcher.ExitProcessor.CoreTest do
  @moduledoc """
  Test of the logic of exit processor - detecting byzantine conditions, emitting events
  """
  use ExUnit.Case, async: true

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core

  require Utxo

  import OMG.Watcher.ExitProcessor.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @not_eth <<1::size(160)>>

  @late_blknum 10_000

  @utxo_pos1 Utxo.position(2, 0, 0)
  @utxo_pos2 Utxo.position(@late_blknum - 1_000, 0, 1)

  @exit_id 1

  defp not_included_competitor_pos do
    <<long::256>> =
      List.duplicate(<<255::8>>, 32)
      |> Enum.reduce(fn val, acc -> val <> acc end)

    long
  end

  setup do
    [alice, bob, carol] = 1..3 |> Enum.map(fn _ -> TestHelper.generate_entity() end)

    transactions = [
      TestHelper.create_recovered([{1, 0, 0, alice}, {1, 2, 1, carol}], [{alice, @eth, 1}, {carol, @eth, 2}]),
      TestHelper.create_recovered([{2, 1, 0, alice}, {2, 2, 1, carol}], [{alice, @not_eth, 1}, {carol, @not_eth, 2}])
    ]

    competing_tx =
      TestHelper.create_recovered([{10, 2, 1, alice}, {1, 0, 0, alice}], [{bob, @eth, 2}, {carol, @eth, 1}])

    unrelated_tx =
      TestHelper.create_recovered([{20, 1, 0, alice}, {20, 20, 1, alice}], [{bob, @eth, 2}, {carol, @eth, 1}])

    {:ok, processor_empty} = Core.init([], [], [])

    in_flight_exit_events =
      transactions |> Enum.zip([2, 4]) |> Enum.map(fn {tx, eth_height} -> ife_event(tx, eth_height: eth_height) end)

    contract_ife_statuses = 1..length(transactions) |> Enum.map(fn i -> {i, i} end)

    ife_tx_hashes = transactions |> Enum.map(&Transaction.raw_txhash/1)

    processor_filled =
      transactions
      |> Enum.zip([2, 4])
      |> Enum.reduce(processor_empty, fn {tx, eth_height}, processor ->
        processor |> start_ife_from(tx, eth_height: eth_height)
      end)

    {:ok,
     %{
       alice: alice,
       bob: bob,
       carol: carol,
       transactions: transactions,
       competing_tx: competing_tx,
       unrelated_tx: unrelated_tx,
       processor_empty: processor_empty,
       in_flight_exit_events: in_flight_exit_events,
       contract_ife_statuses: contract_ife_statuses,
       ife_tx_hashes: ife_tx_hashes,
       processor_filled: processor_filled,
       invalid_piggyback_on_input:
         invalid_piggyback_on_input(processor_filled, transactions, ife_tx_hashes, competing_tx),
       invalid_piggyback_on_output: invalid_piggyback_on_output(alice, processor_filled, transactions, ife_tx_hashes)
     }}
  end

  defp invalid_piggyback_on_input(state, [tx | _], [ife_id | _], competing_tx) do
    state = state |> start_ife_from(competing_tx) |> piggyback_ife_from(ife_id, 0)

    request = %ExitProcessor.Request{
      blknum_now: 4000,
      eth_height_now: 5,
      ife_input_spending_blocks_result: [Block.hashed_txs_at([tx], 3000)]
    }

    state = Core.find_ifes_in_blocks(request, state)

    %{
      state: state,
      request: request,
      ife_input_index: 0,
      ife_txbytes: txbytes(tx),
      spending_txbytes: txbytes(competing_tx),
      spending_input_index: 1,
      spending_sig: sig(competing_tx)
    }
  end

  defp invalid_piggyback_on_output(alice, state, [tx | _], [ife_id | _]) do
    # the piggybacked-output-spending tx is going to be included in a block, which requires more back&forth
    # 1. transaction which is, ife'd, output piggybacked, and included in a block
    # 2. transaction which spends that piggybacked output
    comp = TestHelper.create_recovered([{3000, 0, 0, alice}], [])

    # 3. stuff happens in the contract; output #4 is a double-spend; #5 is OK
    {state, _} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 4}, %{tx_hash: ife_id, output_index: 5}])

    tx_blknum = 3000
    comp_blknum = 4000
    block = Block.hashed_txs_at([tx], tx_blknum)

    exit_processor_request = %ExitProcessor.Request{
      blknum_now: 5000,
      eth_height_now: 5,
      blocks_result: [block],
      ife_input_spending_blocks_result: [
        block,
        Block.hashed_txs_at([comp], comp_blknum)
      ]
    }

    state = Core.find_ifes_in_blocks(exit_processor_request, state)

    %{
      state: state,
      request: exit_processor_request,
      ife_good_pb_index: 5,
      ife_txbytes: txbytes(tx),
      ife_output_pos: Utxo.position(tx_blknum, 0, 0),
      ife_proof: Block.inclusion_proof(block, 0),
      spending_txbytes: txbytes(comp),
      spending_input_index: 0,
      spending_sig: sig(comp),
      ife_input_index: 4
    }
  end

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

  test "can process empty new exits, empty in flight exits or empty finalizations",
       %{processor_empty: empty, processor_filled: filled} do
    assert {^empty, []} = Core.new_exits(empty, [], [])
    assert {^empty, []} = Core.new_in_flight_exits(empty, [], [])
    assert {^filled, []} = Core.new_exits(filled, [], [])
    assert {^filled, []} = Core.new_in_flight_exits(filled, [], [])
    assert {^filled, [], []} = Core.finalize_exits(filled, {[], []})
  end

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

  test "can challenge exits, which are then forgotten completely",
       %{processor_empty: processor, alice: alice} do
    standard_exit_tx1 = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    standard_exit_tx2 = TestHelper.create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 10}, {alice, 10}])

    processor =
      processor
      |> start_se_from(standard_exit_tx1, @utxo_pos1)
      |> start_se_from(standard_exit_tx2, @utxo_pos2)

    # sanity
    assert %ExitProcessor.Request{utxos_to_check: [_, _]} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)

    {processor, _} =
      processor |> Core.challenge_exits([@utxo_pos1, @utxo_pos2] |> Enum.map(&%{utxo_pos: Utxo.Position.encode(&1)}))

    assert %ExitProcessor.Request{utxos_to_check: []} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)
  end

  test "can process challenged exits", %{processor_empty: processor, alice: alice} do
    # see the contract and `Eth.RootChain.get_standard_exit/1` for some explanation why like this
    # this is what an exit looks like after a challenge
    zero_status = {0, 0, 0, 0}
    standard_exit_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    processor = processor |> start_se_from(standard_exit_tx, @utxo_pos1, status: zero_status)

    # sanity
    assert %ExitProcessor.Request{utxos_to_check: [_]} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)

    {processor, _} = processor |> Core.challenge_exits([%{utxo_pos: Utxo.Position.encode(@utxo_pos1)}])

    assert %ExitProcessor.Request{utxos_to_check: []} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)
  end

  test "empty processor returns no exiting utxo positions", %{processor_empty: empty} do
    assert %ExitProcessor.Request{utxos_to_check: []} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, empty)
  end

  test "ifes and standard exits don't interfere",
       %{alice: alice, processor_empty: processor, transactions: [tx | _]} do
    standard_exit_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    processor = processor |> start_se_from(standard_exit_tx, @utxo_pos1) |> start_ife_from(tx)

    assert %{utxos_to_check: [_, Utxo.position(1, 2, 1), @utxo_pos1]} =
             exit_processor_request =
             %ExitProcessor.Request{eth_height_now: 5, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)

    # here it's crucial that the missing utxo related to the ife isn't interpeted as a standard invalid exit
    # that missing utxo isn't enough for any IFE-related event too
    assert {:ok, [%Event.InvalidExit{}]} =
             exit_processor_request
             |> struct!(utxo_exists_result: [false, false, false])
             |> check_validity_filtered(processor, only: [Event.InvalidExit])
  end

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
               txbytes: Transaction.raw_txbytes(tx1),
               txhash: Transaction.raw_txhash(tx1),
               eth_height: 2,
               piggybacked_inputs: [],
               piggybacked_outputs: []
             },
             %{
               txbytes: Transaction.raw_txbytes(tx2),
               txhash: Transaction.raw_txhash(tx2),
               eth_height: 4,
               piggybacked_inputs: [],
               piggybacked_outputs: []
             }
           ] == Core.get_active_in_flight_exits(processor) |> Enum.sort_by(& &1.eth_height)
  end

  test "reports piggybacked inputs/outputs when getting ifes",
       %{processor_empty: processor, transactions: [tx | _]} do
    txhash = Transaction.raw_txhash(tx)
    processor = processor |> start_ife_from(tx)
    assert [%{piggybacked_inputs: [], piggybacked_outputs: []}] = Core.get_active_in_flight_exits(processor)

    processor = piggyback_ife_from(processor, txhash, 0)

    assert [%{piggybacked_inputs: [0], piggybacked_outputs: []}] = Core.get_active_in_flight_exits(processor)

    {processor, _} =
      Core.new_piggybacks(processor, [%{tx_hash: txhash, output_index: 4}, %{tx_hash: txhash, output_index: 5}])

    assert [%{piggybacked_inputs: [0], piggybacked_outputs: [0, 1]}] = Core.get_active_in_flight_exits(processor)
  end

  test "in flight exits sanity checks",
       %{processor_empty: state, in_flight_exit_events: events, contract_ife_statuses: statuses} do
    assert {state, []} == Core.new_in_flight_exits(state, [], [])
    assert {:error, :unexpected_events} == Core.new_in_flight_exits(state, Enum.slice(events, 0, 1), [])
    assert {:error, :unexpected_events} == Core.new_in_flight_exits(state, [], Enum.slice(statuses, 0, 1))
  end

  test "piggybacking sanity checks", %{processor_filled: state, ife_tx_hashes: [ife_id | _]} do
    assert {^state, []} = Core.new_piggybacks(state, [])
    catch_error(Core.new_piggybacks(state, [%{tx_hash: 0, output_index: 0}]))
    catch_error(Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 8}]))

    # cannot piggyback twice the same output
    {updated_state, [_]} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 0}])
    catch_error(Core.new_piggybacks(updated_state, [%{tx_hash: ife_id, output_index: 0}]))
  end

  test "challenges don't affect the list of IFEs returned",
       %{processor_filled: processor, transactions: [tx | _], competing_tx: comp} do
    assert Core.get_active_in_flight_exits(processor) |> Enum.count() == 2
    {processor2, _} = Core.new_ife_challenges(processor, [ife_challenge(tx, comp)])
    assert Core.get_active_in_flight_exits(processor2) |> Enum.count() == 2
    # sanity
    assert processor2 != processor
  end

  test "forgets challenged piggybacks",
       %{processor_filled: processor, ife_tx_hashes: [tx_hash1, tx_hash2]} do
    {processor, _} =
      Core.new_piggybacks(processor, [%{tx_hash: tx_hash1, output_index: 0}, %{tx_hash: tx_hash2, output_index: 0}])

    # sanity: there are some piggybacks after piggybacking, to be removed later
    assert [%{piggybacked_inputs: [_]}, %{piggybacked_inputs: [_]}] = Core.get_active_in_flight_exits(processor)
    {processor, _} = Core.challenge_piggybacks(processor, [%{tx_hash: tx_hash1, output_index: 0}])

    assert [%{txhash: ^tx_hash1, piggybacked_inputs: []}, %{piggybacked_inputs: [0]}] =
             Core.get_active_in_flight_exits(processor)
             |> Enum.sort_by(&length(&1.piggybacked_inputs))
  end

  test "can open and challenge two piggybacks at one call",
       %{processor_filled: processor, ife_tx_hashes: [tx_hash1, tx_hash2]} do
    events = [%{tx_hash: tx_hash1, output_index: 0}, %{tx_hash: tx_hash2, output_index: 0}]

    {processor, _} = Core.new_piggybacks(processor, events)
    # sanity: there are some piggybacks after piggybacking, to be removed later
    assert [%{piggybacked_inputs: [_]}, %{piggybacked_inputs: [_]}] = Core.get_active_in_flight_exits(processor)
    {processor, _} = Core.challenge_piggybacks(processor, events)

    assert [%{piggybacked_inputs: []}, %{piggybacked_inputs: []}] = Core.get_active_in_flight_exits(processor)
  end

  test "detect invalid standard exit based on ife tx which spends same input",
       %{processor_empty: processor, alice: alice} do
    standard_exit_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    tx = TestHelper.create_recovered([{2, 0, 0, alice}], [])
    processor = processor |> start_se_from(standard_exit_tx, @utxo_pos1) |> start_ife_from(tx)
    exiting_utxo = Utxo.Position.encode(@utxo_pos1)

    assert {:ok, [%Event.InvalidExit{utxo_pos: ^exiting_utxo}]} =
             %ExitProcessor.Request{eth_height_now: 5, blknum_now: @late_blknum}
             |> check_validity_filtered(processor, only: [Event.InvalidExit])
  end

  describe "available piggybacks" do
    test "detects multiple available piggybacks, with all the fields",
         %{processor_filled: processor, transactions: [tx1, tx2], alice: alice, carol: carol} do
      txbytes_1 = Transaction.raw_txbytes(tx1)
      txbytes_2 = Transaction.raw_txbytes(tx2)

      assert {:ok, events} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.check_validity(processor)

      assert_events(events, [
        %Event.PiggybackAvailable{
          available_inputs: [%{address: alice.addr, index: 0}, %{address: carol.addr, index: 1}],
          available_outputs: [%{address: alice.addr, index: 0}, %{address: carol.addr, index: 1}],
          txbytes: txbytes_1
        },
        %Event.PiggybackAvailable{
          available_inputs: [%{address: alice.addr, index: 0}, %{address: carol.addr, index: 1}],
          available_outputs: [%{address: alice.addr, index: 0}, %{address: carol.addr, index: 1}],
          txbytes: txbytes_2
        }
      ])
    end

    test "detects available piggyback because tx not seen in valid block, regardless of competitors",
         %{processor_empty: processor, alice: alice} do
      # testing this because everywhere else, the test fixtures always imply competitors
      tx = TestHelper.create_recovered([{1, 0, 0, alice}], [])
      txbytes = txbytes(tx)
      processor = processor |> start_ife_from(tx)

      assert {:ok, [%Event.PiggybackAvailable{txbytes: ^txbytes}]} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.check_validity(processor)
    end

    test "detects available piggyback correctly, even if signed multiple times",
         %{processor_empty: processor, alice: alice} do
      # there is leeway in the contract, that allows IFE transactions to hold non-zero signatures for zero-inputs
      # we want to be sure that this doesn't crash the `ExitProcessor`
      tx = Transaction.new([{1, 0, 0}], [])
      txbytes = txbytes(tx)
      # superfluous signatures
      %{sigs: sigs} = signed_tx = OMG.DevCrypto.sign(tx, [alice.priv, alice.priv, alice.priv])
      processor = processor |> start_ife_from(signed_tx, sigs: sigs)

      assert {:ok, [%Event.PiggybackAvailable{txbytes: ^txbytes}]} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.check_validity(processor)
    end

    test "doesn't detect available piggybacks because txs seen in valid block",
         %{processor_filled: processor, transactions: [tx1, tx2]} do
      txbytes2 = txbytes(tx2)

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([tx1], 3000)]
      }

      assert {:ok, [%Event.PiggybackAvailable{txbytes: ^txbytes2}]} =
               exit_processor_request |> Core.check_validity(processor)
    end

    test "transaction without outputs and different input owners",
         %{alice: alice, bob: bob, processor_empty: processor} do
      tx = TestHelper.create_recovered([{1, 0, 0, alice}, {1, 2, 1, bob}], [])
      alice_addr = alice.addr
      bob_addr = bob.addr
      txbytes = txbytes(tx)
      processor = processor |> start_ife_from(tx)

      assert {:ok,
              [
                %Event.PiggybackAvailable{
                  available_inputs: [%{address: ^alice_addr, index: 0}, %{address: ^bob_addr, index: 1}],
                  available_outputs: [],
                  txbytes: ^txbytes
                }
              ]} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> check_validity_filtered(processor, only: [Event.PiggybackAvailable])
    end

    test "when output is already piggybacked, it is not reported in piggyback available event",
         %{alice: alice, processor_empty: processor} do
      tx = TestHelper.create_recovered([{1, 0, 0, alice}, {1, 2, 1, alice}], [])
      tx_hash = Transaction.raw_txhash(tx)
      processor = processor |> start_ife_from(tx) |> piggyback_ife_from(tx_hash, 0)

      assert {:ok,
              [
                %Event.PiggybackAvailable{
                  available_inputs: [%{index: 1}],
                  available_outputs: []
                }
              ]} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> check_validity_filtered(processor, only: [Event.PiggybackAvailable])
    end

    test "when ife is finalized, it's outputs are not reported as available for piggyback",
         %{alice: alice, processor_empty: processor} do
      tx = TestHelper.create_recovered([{1, 0, 0, alice}, {1, 2, 1, alice}], [])
      tx_hash = Transaction.raw_txhash(tx)
      processor = processor |> start_ife_from(tx) |> piggyback_ife_from(tx_hash, 0)
      finalization = %{in_flight_exit_id: @exit_id, output_index: 0}
      {:ok, processor, _} = Core.finalize_in_flight_exits(processor, [finalization], %{})

      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> check_validity_filtered(processor, only: [Event.PiggybackAvailable])
    end

    test "challenged IFEs emit the same piggybacks as canonical ones",
         %{processor_filled: processor, transactions: [tx | _], competing_tx: comp} do
      assert {:ok, events_canonical} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> Core.check_validity(processor)

      {challenged_processor, _} = Core.new_ife_challenges(processor, [ife_challenge(tx, comp)])

      assert {:ok, events_challenged} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.check_validity(challenged_processor)

      assert_events(events_canonical, events_challenged)
    end
  end

  describe "evaluates correctness of new piggybacks" do
    test "detects double-spend of an input, found in IFE",
         %{processor_filled: state, transactions: [tx | _], competing_tx: comp, ife_tx_hashes: [ife_id | _]} do
      txbytes = txbytes(tx)
      {comp_txbytes, other_sig} = {txbytes(comp), sig(comp, 1)}
      state = state |> start_ife_from(comp) |> piggyback_ife_from(ife_id, 0)
      request = %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}

      assert {:ok, [%Event.InvalidPiggyback{txbytes: ^txbytes, inputs: [0], outputs: []}]} =
               check_validity_filtered(request, state, only: [Event.InvalidPiggyback])

      assert {:ok,
              %{
                in_flight_input_index: 0,
                in_flight_txbytes: ^txbytes,
                spending_txbytes: ^comp_txbytes,
                spending_input_index: 1,
                spending_sig: ^other_sig
              }} = Core.get_input_challenge_data(request, state, txbytes, 0)
    end

    test "detects double-spend of an input, found in a block",
         %{processor_filled: state, transactions: [tx | _], competing_tx: comp, ife_tx_hashes: [ife_id | _]} do
      txbytes = txbytes(tx)
      {comp_txbytes, comp_sig} = {txbytes(comp), sig(comp, 1)}

      state = piggyback_ife_from(state, ife_id, 0)

      comp_blknum = 4000

      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([comp], comp_blknum)]
      }

      state = Core.find_ifes_in_blocks(request, state)

      assert {:ok, [%Event.InvalidPiggyback{txbytes: ^txbytes, inputs: [0], outputs: []}]} =
               check_validity_filtered(request, state, only: [Event.InvalidPiggyback])

      assert {:ok,
              %{
                in_flight_input_index: 0,
                in_flight_txbytes: ^txbytes,
                spending_txbytes: ^comp_txbytes,
                spending_input_index: 1,
                spending_sig: ^comp_sig
              }} = Core.get_input_challenge_data(request, state, txbytes, 0)
    end

    test "detects double-spend of an output, found in a IFE",
         %{alice: alice, processor_filled: state, transactions: [tx | _], ife_tx_hashes: [ife_id | _]} do
      # 1. transaction which is, ife'd, output piggybacked, and included in a block
      txbytes = txbytes(tx)
      tx_blknum = 3000

      # 2. transaction which spends that piggybacked output
      comp = TestHelper.create_recovered([{tx_blknum, 0, 0, alice}], [])
      {comp_txbytes, comp_signature} = {txbytes(comp), sig(comp)}

      # 3. stuff happens in the contract
      state = state |> start_ife_from(comp) |> piggyback_ife_from(ife_id, 4)

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        ife_input_spending_blocks_result: [Block.hashed_txs_at([tx], tx_blknum)]
      }

      state = Core.find_ifes_in_blocks(exit_processor_request, state)

      assert {:ok, [%Event.InvalidPiggyback{txbytes: ^txbytes, inputs: [], outputs: [0]}]} =
               check_validity_filtered(exit_processor_request, state, only: [Event.InvalidPiggyback])

      assert {:ok,
              %{
                in_flight_output_pos: Utxo.position(^tx_blknum, 0, 0),
                in_flight_proof: proof_bytes,
                in_flight_txbytes: ^txbytes,
                spending_txbytes: ^comp_txbytes,
                spending_input_index: 0,
                spending_sig: ^comp_signature
              }} = Core.get_output_challenge_data(exit_processor_request, state, txbytes, 0)

      assert_proof_sound(proof_bytes)
    end

    test "detects double-spend of an output, found in a block",
         %{alice: alice, processor_filled: state, transactions: [tx | _], ife_tx_hashes: [ife_id | _]} do
      # this time, the piggybacked-output-spending tx is going to be included in a block, which requires more back&forth
      # 1. transaction which is, ife'd, output piggybacked, and included in a block
      txbytes = txbytes(tx)
      tx_blknum = 3000

      # 2. transaction which spends that piggybacked output
      comp = TestHelper.create_recovered([{tx_blknum, 0, 0, alice}], [])
      {comp_txbytes, comp_signature} = {txbytes(comp), sig(comp)}

      # 3. stuff happens in the contract
      state = piggyback_ife_from(state, ife_id, 4)

      comp_blknum = 4000

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        ife_input_spending_blocks_result: [
          Block.hashed_txs_at([tx], tx_blknum)
        ]
      }

      state = Core.find_ifes_in_blocks(exit_processor_request, state)

      exit_processor_request = %{
        exit_processor_request
        | blocks_result: [Block.hashed_txs_at([comp], comp_blknum)]
      }

      assert {:ok, [%Event.InvalidPiggyback{txbytes: ^txbytes, inputs: [], outputs: [0]}]} =
               check_validity_filtered(exit_processor_request, state, only: [Event.InvalidPiggyback])

      assert {:ok,
              %{
                in_flight_output_pos: Utxo.position(^tx_blknum, 0, 0),
                in_flight_proof: proof_bytes,
                in_flight_txbytes: ^txbytes,
                spending_txbytes: ^comp_txbytes,
                spending_input_index: 0,
                spending_sig: ^comp_signature
              }} = Core.get_output_challenge_data(exit_processor_request, state, txbytes, 0)

      assert_proof_sound(proof_bytes)
    end

    test "does not look into ife_input_spending_blocks_result when it should not",
         %{processor_filled: state, transactions: [tx | _], ife_tx_hashes: [ife_id | _]} do
      txbytes = txbytes(tx)
      tx_blknum = 3000

      state = piggyback_ife_from(state, ife_id, 4)

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        ife_input_spending_blocks_result: [
          Block.hashed_txs_at([tx], tx_blknum)
        ]
      }

      state = Core.find_ifes_in_blocks(exit_processor_request, state)

      exit_processor_request = %{
        exit_processor_request
        | blocks_result: [],
          ife_input_spending_blocks_result: nil
      }

      assert {:ok, []} = check_validity_filtered(exit_processor_request, state, only: [Event.InvalidPiggyback])

      assert {:error, :no_double_spend_on_particular_piggyback} =
               Core.get_output_challenge_data(exit_processor_request, state, txbytes, 0)
    end

    test "handles well situation when syncing is in progress",
         %{processor_filled: state, ife_tx_hashes: [ife_id | _]} do
      state = piggyback_ife_from(state, ife_id, 4)

      assert %ExitProcessor.Request{utxos_to_check: [], ife_input_utxos_to_check: []} =
               %ExitProcessor.Request{eth_height_now: 13, blknum_now: 0}
               |> Core.determine_ife_input_utxos_existence_to_get(state)
               |> Core.determine_utxo_existence_to_get(state)
    end

    test "seeks piggybacked-output-spending txs in blocks",
         %{processor_filled: processor, transactions: [tx | _], ife_tx_hashes: [ife_id | _]} do
      # if an output-piggybacking transaction is included in some block, we need to seek blocks that could be spending
      processor = piggyback_ife_from(processor, ife_id, 4)

      tx_blknum = 3000

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([tx], tx_blknum)]
      }

      # for one piggybacked output, we're asking for its inputs positions to check utxo existence
      request = Core.determine_ife_input_utxos_existence_to_get(exit_processor_request, processor)
      assert Utxo.position(1, 0, 0) in request.ife_input_utxos_to_check
      assert Utxo.position(1, 2, 1) in request.ife_input_utxos_to_check

      # if it turns out to not exists, we're fetching the spending block
      request =
        exit_processor_request
        |> struct!(%{ife_input_utxos_to_check: [Utxo.position(1, 0, 0)], ife_input_utxo_exists_result: [false]})
        |> Core.determine_ife_spends_to_get(processor)

      assert Utxo.position(1, 0, 0) in request.ife_input_spends_to_get
    end

    test "detects multiple double-spends in single IFE",
         %{alice: alice, processor_filled: state, transactions: [tx | _], ife_tx_hashes: [ife_id | _]} do
      tx_blknum = 3000
      txbytes = txbytes(tx)

      comp =
        TestHelper.create_recovered(
          [{1, 0, 0, alice}, {1, 2, 1, alice}, {tx_blknum, 0, 0, alice}, {tx_blknum, 0, 1, alice}],
          []
        )

      {comp_txbytes, alice_sig} = {txbytes(comp), sig(comp)}
      state = state |> start_ife_from(comp)

      state =
        state
        |> piggyback_ife_from(ife_id, 0)
        |> piggyback_ife_from(ife_id, 1)
        |> piggyback_ife_from(ife_id, 4)
        |> piggyback_ife_from(ife_id, 5)

      request = %ExitProcessor.Request{
        blknum_now: 4000,
        eth_height_now: 5,
        ife_input_spending_blocks_result: [Block.hashed_txs_at([tx], tx_blknum)]
      }

      state = Core.find_ifes_in_blocks(request, state)

      assert {:ok, [%Event.InvalidPiggyback{txbytes: ^txbytes, inputs: [0, 1], outputs: [0, 1]}]} =
               check_validity_filtered(request, state, only: [Event.InvalidPiggyback])

      assert {:ok,
              %{
                in_flight_input_index: 1,
                in_flight_txbytes: ^txbytes,
                spending_txbytes: ^comp_txbytes,
                spending_input_index: 1,
                spending_sig: ^alice_sig
              }} = Core.get_input_challenge_data(request, state, txbytes, 1)

      assert {:ok,
              %{
                in_flight_txbytes: ^txbytes,
                in_flight_output_pos: Utxo.position(^tx_blknum, 0, 0),
                in_flight_proof: inclusion_proof,
                spending_txbytes: ^comp_txbytes,
                spending_input_index: 2,
                spending_sig: ^alice_sig
              }} = Core.get_output_challenge_data(request, state, txbytes, 0)

      assert_proof_sound(inclusion_proof)
    end
  end

  describe "produces challenges for bad piggybacks" do
    test "produces single challenge proof on double-spent piggyback input",
         %{
           invalid_piggyback_on_input: %{
             state: state,
             request: request,
             ife_input_index: ife_input_index,
             ife_txbytes: ife_txbytes,
             spending_txbytes: spending_txbytes,
             spending_input_index: spending_input_index,
             spending_sig: spending_sig
           }
         } do
      assert {:ok,
              %{
                in_flight_input_index: ^ife_input_index,
                in_flight_txbytes: ^ife_txbytes,
                spending_txbytes: ^spending_txbytes,
                spending_input_index: ^spending_input_index,
                spending_sig: ^spending_sig
              }} = Core.get_input_challenge_data(request, state, ife_txbytes, ife_input_index)
    end

    test "fail when asked to produce proof for wrong oindex",
         %{
           invalid_piggyback_on_input: %{
             state: state,
             request: request,
             ife_input_index: bad_pb_output,
             ife_txbytes: txbytes
           }
         } do
      assert bad_pb_output != 1

      assert {:error, :no_double_spend_on_particular_piggyback} =
               Core.get_input_challenge_data(request, state, txbytes, 1)
    end

    test "fail when asked to produce proof for wrong txhash",
         %{invalid_piggyback_on_input: %{state: state, request: request}, unrelated_tx: comp} do
      comp_txbytes = Transaction.raw_txbytes(comp)
      assert {:error, :unknown_ife} = Core.get_input_challenge_data(request, state, comp_txbytes, 0)
      assert {:error, :unknown_ife} = Core.get_output_challenge_data(request, state, comp_txbytes, 0)
    end

    test "fail when asked to produce proof for wrong badly encoded tx",
         %{invalid_piggyback_on_input: %{state: state, request: request}} do
      assert {:error, :malformed_transaction} = Core.get_input_challenge_data(request, state, <<0>>, 0)
      assert {:error, :malformed_transaction} = Core.get_output_challenge_data(request, state, <<0>>, 0)
    end

    test "fail when asked to produce proof for illegal oindex",
         %{invalid_piggyback_on_input: %{state: state, request: request, ife_txbytes: txbytes}} do
      assert {:error, :piggybacked_index_out_of_range} = Core.get_input_challenge_data(request, state, txbytes, -1)
      assert {:error, :piggybacked_index_out_of_range} = Core.get_output_challenge_data(request, state, txbytes, -1)
    end

    test "will fail if asked to produce proof for wrong output",
         %{
           invalid_piggyback_on_output: %{
             state: state,
             request: request,
             ife_input_index: bad_pb_output,
             ife_txbytes: txbytes
           }
         } do
      assert 2 != bad_pb_output - 4

      assert {:error, :no_double_spend_on_particular_piggyback} =
               Core.get_output_challenge_data(request, state, txbytes, 2)
    end

    test "will fail if asked to produce proof for correct piggyback on output",
         %{
           invalid_piggyback_on_output: %{
             state: state,
             request: request,
             ife_good_pb_index: good_pb_output,
             ife_txbytes: txbytes
           }
         } do
      assert {:error, :no_double_spend_on_particular_piggyback} =
               Core.get_output_challenge_data(request, state, txbytes, good_pb_output - 4)
    end
  end

  describe "finds competitors and allows canonicity challenges" do
    test "none if input never spent elsewhere",
         %{processor_filled: processor} do
      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])
    end

    test "none if different input spent in some tx from appendix",
         %{processor_filled: processor, transactions: [tx1 | _], unrelated_tx: comp} do
      txbytes = txbytes(tx1)
      processor = processor |> start_ife_from(comp)

      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])

      assert {:error, :competitor_not_found} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "none if different input spent in some tx from block",
         %{processor_filled: processor, transactions: [tx1 | _], unrelated_tx: comp} do
      txbytes = txbytes(tx1)

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([comp], 3000)]
      }

      assert {:ok, []} =
               exit_processor_request |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])

      assert {:error, :competitor_not_found} = exit_processor_request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "none if input spent in _same_ tx in block",
         %{processor_filled: processor, transactions: [tx1 | _]} do
      txbytes = txbytes(tx1)

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([tx1], 3000)]
      }

      assert {:ok, []} =
               exit_processor_request |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])

      assert {:error, :competitor_not_found} =
               exit_processor_request
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "none if input spent in _same_ tx in tx appendix",
         %{processor_filled: processor, transactions: [tx | _]} do
      txbytes = txbytes(tx)
      processor = processor |> start_ife_from(tx)

      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])

      assert {:error, :competitor_not_found} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "each other, if input spent in different ife",
         %{processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      txbytes = txbytes(tx1)
      {comp_txbytes, comp_signature} = {txbytes(comp), sig(comp)}
      processor = processor |> start_ife_from(comp)

      assert {:ok, events} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

      # no invalid piggyback events are generated
      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> check_validity_filtered(processor, only: [Event.InvalidPiggyback])

      assert_events(events, [%Event.NonCanonicalIFE{txbytes: txbytes}, %Event.NonCanonicalIFE{txbytes: comp_txbytes}])

      assert {:ok,
              %{
                in_flight_txbytes: ^txbytes,
                in_flight_input_index: 0,
                competing_txbytes: ^comp_txbytes,
                competing_input_index: 1,
                competing_sig: ^comp_signature,
                competing_tx_pos: Utxo.position(0, 0, 0),
                competing_proof: ""
              }} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "a competitor that's submitted as challenge to other IFE",
         %{alice: alice, processor_filled: processor, transactions: [tx1, tx2 | _]} do
      # ifes in processor here aren't competitors to each other, but the challenge filed for tx2 is a competitor
      # for tx1, which is what we want to detect:
      comp = TestHelper.create_recovered([{1, 0, 0, alice}, {2, 1, 0, alice}], [])
      {comp_txbytes, comp_signature} = {txbytes(comp), sig(comp)}
      txbytes = Transaction.raw_txbytes(tx1)
      challenge_event = ife_challenge(tx2, comp)
      {processor, _} = Core.new_ife_challenges(processor, [challenge_event])

      exit_processor_request = %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}

      assert {:ok, [%Event.NonCanonicalIFE{txbytes: ^txbytes}]} =
               exit_processor_request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

      assert {:ok,
              %{
                in_flight_txbytes: ^txbytes,
                competing_txbytes: ^comp_txbytes,
                competing_input_index: 0,
                competing_sig: ^comp_signature
              }} = exit_processor_request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "a single competitor included in a block, with proof",
         %{processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      txbytes = txbytes(tx1)
      {comp_txbytes, comp_signature} = {txbytes(comp), sig(comp)}

      other_blknum = 3000

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([comp], other_blknum)]
      }

      assert {:ok, [%Event.NonCanonicalIFE{txbytes: ^txbytes}]} =
               exit_processor_request
               |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

      assert {:ok,
              %{
                in_flight_txbytes: ^txbytes,
                in_flight_input_index: 0,
                competing_txbytes: ^comp_txbytes,
                competing_input_index: 1,
                competing_sig: ^comp_signature,
                competing_tx_pos: Utxo.position(^other_blknum, 0, 0),
                competing_proof: proof_bytes
              }} =
               exit_processor_request
               |> Core.get_competitor_for_ife(processor, txbytes)

      assert_proof_sound(proof_bytes)
    end

    test "handle two competitors, when the younger one already challenged",
         %{processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      txbytes = txbytes(tx1)
      comp_txbytes = txbytes(comp)
      other_blknum = 3000

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([comp, comp], other_blknum)]
      }

      # the transaction is firstmost submitted as a competitor and used to challenge with no inclusion proof
      processor = processor |> start_ife_from(comp)
      challenge = ife_challenge(tx1, comp)

      # sanity check - there's two non-canonicals, because IFE compete with each other
      # after the first challenge there should be only one, after the final challenge - none
      assert {:ok, [_, _]} = exit_processor_request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

      assert_competitors_work = fn processor ->
        # should be `assert {:ok, [_, _]}` but we have OMG-441 (see other comment)
        assert {:ok, [_]} = exit_processor_request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

        assert {:ok, %{competing_txbytes: ^comp_txbytes, competing_tx_pos: Utxo.position(^other_blknum, 0, 0)}} =
                 exit_processor_request |> Core.get_competitor_for_ife(processor, txbytes)
      end

      # challenge with IFE (no position)
      {processor, _} = Core.new_ife_challenges(processor, [challenge])
      assert_competitors_work.(processor)

      # challenge with the younger competitor (incomplete challenge)
      young_challenge = ife_challenge(tx1, comp, competitor_position: Utxo.position(other_blknum, 1, 0))
      {processor, _} = Core.new_ife_challenges(processor, [young_challenge])
      assert_competitors_work.(processor)

      # challenge with the older competitor (final)
      older_challenge = ife_challenge(tx1, comp, competitor_position: Utxo.position(other_blknum, 0, 0))
      {processor, _} = Core.new_ife_challenges(processor, [older_challenge])
      # NOTE: should be like this - only the "other" IFE remains challenged, because our main one got challenged by the
      # oldest competitor now):
      # assert {:ok, [_]} = exit_processor_request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])?
      #
      # i.e. if the challenge present is no the oldest competitor, we still should challenge. After it is the oldest
      # we stop bothering, see OMG-441
      #
      # this is temporary behavior being tested:
      assert_competitors_work.(processor)
    end

    test "none if IFE is challenged enough already",
         %{processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      txbytes = txbytes(tx1)
      comp_txbytes = txbytes(comp)
      other_blknum = 3000

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([comp], other_blknum)]
      }

      challenge =
        ife_challenge(tx1, comp, competitor_position: Utxo.position(other_blknum, 0, 0), competing_tx_input_index: 1)

      {processor, _} = Core.new_ife_challenges(processor, [challenge])

      assert {:ok, []} = exit_processor_request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

      # getting the competitor is still valid, so allowing this
      assert {:ok, %{competing_txbytes: ^comp_txbytes, competing_tx_pos: Utxo.position(other_blknum, 0, 0)}} =
               exit_processor_request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "a competitor having the double-spend on various input indices",
         %{alice: alice, processor_empty: processor} do
      tx = TestHelper.create_recovered([{1, 0, 0, alice}, {1, 2, 1, alice}], [])
      txbytes = txbytes(tx)
      processor = processor |> start_ife_from(tx)

      input_spent_in_idx0 = {1, 0, 0}
      input_spent_in_idx1 = {1, 2, 1}
      other_input1 = {110, 2, 1}
      other_input2 = {111, 2, 1}
      other_input3 = {112, 2, 1}

      comps = [
        Transaction.new([input_spent_in_idx0], []),
        Transaction.new([other_input1, input_spent_in_idx0], []),
        Transaction.new([other_input1, other_input2, input_spent_in_idx0], []),
        Transaction.new([other_input1, other_input2, other_input3, input_spent_in_idx0], []),
        Transaction.new([input_spent_in_idx1], []),
        Transaction.new([other_input1, input_spent_in_idx1], []),
        Transaction.new([other_input1, other_input2, input_spent_in_idx1], []),
        Transaction.new([other_input1, other_input2, other_input3, input_spent_in_idx1], [])
      ]

      expected_input_ids = [{0, 0}, {1, 0}, {2, 0}, {3, 0}, {0, 1}, {1, 1}, {2, 1}, {3, 1}]

      check = fn {comp, {competing_input_index, in_flight_input_index}} ->
        # unfortunately, transaction validity requires us to duplicate a signature for every non-zero input
        required_priv_key_list =
          comp
          |> Transaction.get_inputs()
          |> Enum.count()
          |> (&List.duplicate(alice.priv, &1)).()

        other_recovered = OMG.TestHelper.sign_recover!(comp, required_priv_key_list)

        exit_processor_request = %ExitProcessor.Request{
          blknum_now: 5000,
          eth_height_now: 5,
          blocks_result: [Block.hashed_txs_at([other_recovered], 3000)]
        }

        assert {:ok, [%Event.NonCanonicalIFE{txbytes: ^txbytes}]} =
                 exit_processor_request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

        assert {:ok,
                %{
                  in_flight_input_index: ^in_flight_input_index,
                  competing_input_index: ^competing_input_index
                }} =
                 exit_processor_request
                 |> Core.get_competitor_for_ife(processor, txbytes)
      end

      comps
      |> Enum.zip(expected_input_ids)
      |> Enum.each(check)
    end

    test "a competitor being signed on various positions",
         %{processor_filled: processor, transactions: [tx1 | _], alice: alice, bob: bob} do
      comp = TestHelper.create_recovered([{10, 2, 1, bob}, {1, 0, 0, alice}], [])
      comp_signature = sig(comp, 1)

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([comp], 3000)]
      }

      assert {:ok, %{competing_sig: ^comp_signature}} =
               exit_processor_request |> Core.get_competitor_for_ife(processor, txbytes(tx1))
    end

    test "a best competitor, included earliest in a block, regardless of conflicting utxo position",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      # NOTE that the recent competitor spends an __older__ input. Also note the reversing of block results done below
      #      Regardless of these, the best competitor (from blknum 2000) must always be returned
      # NOTE also that non-included competitors always are considered last, and hence worst and never are returned

      # first the included competitors
      recovered_recent = TestHelper.create_recovered([{1, 0, 0, alice}], [])
      recovered_oldest = TestHelper.create_recovered([{1, 0, 0, alice}, {2, 2, 1, alice}], [])

      # ife-related competitor
      processor = processor |> start_ife_from(comp)

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([recovered_oldest], 2000), Block.hashed_txs_at([recovered_recent], 3000)]
      }

      txbytes = txbytes(tx1)

      assert {:ok, %{competing_tx_pos: Utxo.position(2000, 0, 0)}} =
               exit_processor_request
               |> Core.get_competitor_for_ife(processor, txbytes)

      assert {:ok, %{competing_tx_pos: Utxo.position(2000, 0, 0)}} =
               exit_processor_request
               |> Map.update!(:blocks_result, &Enum.reverse/1)
               |> struct!()
               |> Core.get_competitor_for_ife(processor, txbytes)

      # check also that the rule applies to order of txs within a block
      assert {:ok, %{competing_tx_pos: Utxo.position(2000, 0, 0)}} =
               exit_processor_request
               |> Map.put(:blocks_result, [Block.hashed_txs_at([recovered_oldest, recovered_recent], 2000)])
               |> struct!()
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "by asking for utxo existence concerning active ifes and standard exits",
         %{processor_empty: processor, alice: alice} do
      standard_exit_tx = TestHelper.create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 10}, {alice, 10}])
      ife_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
      processor = processor |> start_se_from(standard_exit_tx, @utxo_pos2) |> start_ife_from(ife_tx)

      assert %{utxos_to_check: [Utxo.position(1, 0, 0), @utxo_pos2]} =
               %ExitProcessor.Request{blknum_now: @late_blknum}
               |> Core.determine_utxo_existence_to_get(processor)
    end

    test "by asking for utxo spends concerning active ifes",
         %{processor_filled: processor} do
      assert %{spends_to_get: [Utxo.position(1, 2, 1)]} =
               %ExitProcessor.Request{
                 utxos_to_check: [Utxo.position(1, 2, 1), Utxo.position(112, 2, 1)],
                 utxo_exists_result: [false, false]
               }
               |> Core.determine_spends_to_get(processor)
    end

    test "by not asking for utxo spends concerning non-active ifes",
         %{processor_empty: processor, transactions: [tx | _]} do
      processor = processor |> start_ife_from(tx, status: {0, @exit_id})

      assert %{utxos_to_check: []} =
               %ExitProcessor.Request{blknum_now: @late_blknum} |> Core.determine_utxo_existence_to_get(processor)
    end

    test "by not asking for utxo existence concerning finalized ifes",
         %{processor_empty: processor, transactions: [tx | _]} do
      tx_hash = Transaction.raw_txhash(tx)
      piggybacks = [%{tx_hash: tx_hash, output_index: 1}, %{tx_hash: tx_hash, output_index: 2}]
      ife_id = 123
      {processor, _} = processor |> start_ife_from(tx, status: {1, ife_id}) |> Core.new_piggybacks(piggybacks)
      finalizations = [%{in_flight_exit_id: ife_id, output_index: 1}, %{in_flight_exit_id: ife_id, output_index: 2}]
      {:ok, processor, _} = Core.finalize_in_flight_exits(processor, finalizations, %{})

      assert %{utxos_to_check: []} =
               %ExitProcessor.Request{blknum_now: @late_blknum} |> Core.determine_utxo_existence_to_get(processor)
    end

    test "by not asking for spends on no ifes",
         %{processor_empty: processor} do
      assert %{spends_to_get: []} =
               %ExitProcessor.Request{utxos_to_check: [Utxo.position(1, 0, 0)], utxo_exists_result: [false]}
               |> Core.determine_spends_to_get(processor)
    end

    test "none if input not yet created during sync",
         %{processor_filled: processor} do
      assert %{utxos_to_check: to_check} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 13}
               |> Core.determine_utxo_existence_to_get(processor)

      assert Utxo.position(9000, 0, 1) not in to_check
    end

    test "for nonexistent tx doesn't crash",
         %{transactions: [tx | _], processor_empty: processor} do
      txbytes = Transaction.raw_txbytes(tx)

      assert {:error, :ife_not_known_for_tx} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "for malformed input txbytes doesn't crash",
         %{processor_empty: processor} do
      assert {:error, :malformed_transaction} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, <<0>>)
    end
  end

  describe "detects the need and allows to respond to canonicity challenges" do
    test "against a competitor",
         %{processor_filled: processor, transactions: [tx1 | _] = txs, competing_tx: comp} do
      {challenged_processor, _} = Core.new_ife_challenges(processor, [ife_challenge(tx1, comp)])
      txbytes = Transaction.raw_txbytes(tx1)
      other_blknum = 3000

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at(txs, other_blknum)]
      }

      assert {:ok, [%Event.InvalidIFEChallenge{txbytes: ^txbytes}]} =
               exit_processor_request |> Core.check_validity(challenged_processor)

      assert {:ok,
              %{
                in_flight_txbytes: ^txbytes,
                in_flight_tx_pos: Utxo.position(^other_blknum, 0, 0),
                in_flight_proof: proof_bytes
              }} =
               exit_processor_request
               |> Core.prove_canonical_for_ife(txbytes)

      assert_proof_sound(proof_bytes)
    end

    test "proving canonical for nonexistent tx doesn't crash", %{transactions: [tx | _]} do
      txbytes = Transaction.raw_txbytes(tx)

      assert {:error, :canonical_not_found} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.prove_canonical_for_ife(txbytes)
    end

    test "for malformed input txbytes doesn't crash" do
      assert {:error, :malformed_transaction} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5} |> Core.prove_canonical_for_ife(<<0>>)
    end

    test "none if ifes are canonical", %{processor_filled: processor} do
      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])
    end

    # TODO: implement more behavior tests
    test "none if challenge gets responded and ife canonical",
         %{} do
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

      ife1_exits = {[Utxo.position(1, 0, 0)], []}
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

  defp assert_proof_sound(proof_bytes) do
    # NOTE: checking of actual proof working up to the contract integration test
    assert is_binary(proof_bytes)
    # hash size * merkle tree depth
    assert byte_size(proof_bytes) == 32 * 16
  end

  defp assert_events(events, expected_events) do
    assert MapSet.new(events) == MapSet.new(expected_events)
  end

  defp check_validity_filtered(request, processor, opts) do
    exclude_events = Keyword.get(opts, :exclude, [])
    only_events = Keyword.get(opts, :only, [])

    {result, events} = Core.check_validity(request, processor)

    any? = fn filtering_events, event ->
      Enum.any?(filtering_events, fn filtering_event -> event.__struct__ == filtering_event end)
    end

    filtered_events =
      events
      |> Enum.filter(fn event ->
        Enum.empty?(exclude_events) or not any?.(exclude_events, event)
      end)
      |> Enum.filter(fn event ->
        Enum.empty?(only_events) or any?.(only_events, event)
      end)

    {result, filtered_events}
  end

  defp ife_challenge(tx, comp, opts \\ []) do
    competitor_position = Keyword.get(opts, :competitor_position)

    competitor_position =
      if competitor_position, do: Utxo.Position.encode(competitor_position), else: not_included_competitor_pos()

    %{
      tx_hash: Transaction.raw_txhash(tx),
      competitor_position: competitor_position,
      call_data: %{
        competing_tx: txbytes(comp),
        competing_tx_input_index: Keyword.get(opts, :competing_tx_input_index, 0),
        competing_tx_sig: Keyword.get(opts, :competing_tx_sig, sig(comp))
      }
    }
  end

  defp sigs(tx), do: tx.signed_tx.sigs
  defp sig(tx, idx \\ 0), do: tx |> sigs() |> Enum.at(idx)
  defp txbytes(tx), do: Transaction.raw_txbytes(tx)
end
