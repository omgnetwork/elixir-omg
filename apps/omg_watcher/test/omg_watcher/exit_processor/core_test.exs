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

defmodule OmgWatcher.ExitProcessor.CoreTest do
  @moduledoc """
  Test of the logic of exit processor - detecting byzantine conditions, emitting events, talking to OMG.State.Core
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.Fixtures

  alias OMG.Block
  alias OMG.Crypto
  alias OMG.DevCrypto
  alias OMG.State
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OmgWatcher.Event
  alias OmgWatcher.ExitProcessor
  alias OmgWatcher.ExitProcessor.Core
  alias OmgWatcher.ExitProcessor.ExitInfo

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @not_eth <<1::size(160)>>
  @zero_address OMG.Eth.zero_address()

  @early_blknum 1_000
  @late_blknum 10_000

  @utxo_pos1 Utxo.position(2, 0, 0)
  @utxo_pos2 Utxo.position(@late_blknum - 1_000, 0, 1)
  @utxo_pos3 Utxo.position(1, 0, 0)

  @non_zero_exit_id 1
  @zero_sig <<0::520>>

  defp not_included_competitor_pos do
    <<long::256>> =
      List.duplicate(<<255::8>>, 32)
      |> Enum.reduce(fn val, acc -> val <> acc end)

    long
  end

  deffixture transactions(alice, carol) do
    [
      Transaction.new([{1, 0, 0}, {1, 2, 1}], [{alice.addr, @eth, 1}, {carol.addr, @eth, 2}]),
      Transaction.new([{2, 1, 0}, {2, 2, 1}], [{alice.addr, @eth, 1}, {carol.addr, @eth, 2}])
    ]
  end

  deffixture competing_transactions(alice, bob, carol) do
    [
      Transaction.new([{10, 2, 1}, {1, 0, 0}], [{bob.addr, @eth, 2}, {carol.addr, @eth, 1}]),
      Transaction.new([{1, 0, 0}, {10, 2, 1}], [{alice.addr, @eth, 2}, {bob.addr, @eth, 1}]),
      Transaction.new([{20, 1, 0}, {20, 20, 1}], [{bob.addr, @eth, 2}, {carol.addr, @eth, 1}])
    ]
  end

  deffixture processor_empty() do
    {:ok, empty} = Core.init([], [], [])
    empty
  end

  # events is whatever `OMG.Eth` would feed into the `OmgWatcher.ExitProcessor`, via `OMG.EthereumEventListener`
  deffixture exit_events(alice, transactions) do
    [txbytes1, txbytes2] = transactions |> Enum.map(&Transaction.raw_txbytes/1)

    [
      %{
        owner: alice.addr,
        eth_height: 2,
        exit_id: 1,
        call_data: %{utxo_pos: Utxo.Position.encode(@utxo_pos1), output_tx: txbytes1}
      },
      %{
        owner: alice.addr,
        eth_height: 4,
        exit_id: 2,
        call_data: %{utxo_pos: Utxo.Position.encode(@utxo_pos2), output_tx: txbytes2}
      }
    ]
  end

  # extracts the mocked responses of the `Eth.RootChain.get_standard_exit` for the exit events
  # all exits active (owner non-zero). This is the auxiliary, second argument that's fed into `new_exits`
  deffixture contract_exit_statuses(alice) do
    [
      {alice.addr, @eth, 10, Utxo.Position.encode(@utxo_pos1)},
      {alice.addr, @not_eth, 9, Utxo.Position.encode(@utxo_pos2)}
    ]
  end

  deffixture in_flight_exit_events(transactions, alice) do
    [tx1_bytes, tx2_bytes] =
      transactions
      |> Enum.map(&Transaction.raw_txbytes/1)

    [tx1_sigs, tx2_sigs] =
      transactions
      |> Enum.map(&DevCrypto.sign(&1, [alice.priv, alice.priv]))
      |> Enum.map(&Enum.join(&1.sigs))

    [
      %{call_data: %{in_flight_tx: tx1_bytes, in_flight_tx_sigs: tx1_sigs}, eth_height: 2},
      %{call_data: %{in_flight_tx: tx2_bytes, in_flight_tx_sigs: tx2_sigs}, eth_height: 4}
    ]
  end

  deffixture contract_ife_statuses(in_flight_exit_events) do
    1..length(in_flight_exit_events)
    |> Enum.map(fn i -> {i, i} end)
  end

  deffixture ife_tx_hashes(transactions) do
    transactions |> Enum.map(&Transaction.raw_txhash/1)
  end

  deffixture in_flight_exits_challenges_events(ife_tx_hashes, competing_transactions) do
    [tx1_hash, tx2_hash] = ife_tx_hashes
    [competing_tx1, competing_tx2, competing_tx3] = competing_transactions

    [
      %{
        tx_hash: tx1_hash,
        # in-flight transaction
        competitor_position: not_included_competitor_pos(),
        call_data: %{
          competing_tx: Transaction.raw_txbytes(competing_tx1),
          competing_tx_input_index: 1,
          competing_tx_sig: @zero_sig
        }
      },
      %{
        tx_hash: tx1_hash,
        # canonical transaction
        competitor_position: Utxo.position(1000, 0, 0) |> Utxo.Position.encode(),
        call_data: %{
          competing_tx: Transaction.raw_txbytes(competing_tx2),
          competing_tx_input_index: 1,
          competing_tx_sig: @zero_sig
        }
      },
      %{
        tx_hash: tx2_hash,
        # in-flight transaction
        competitor_position: not_included_competitor_pos(),
        call_data: %{
          competing_tx: Transaction.raw_txbytes(competing_tx3),
          competing_tx_input_index: 2,
          competing_tx_sig: <<1::520>>
        }
      }
    ]
  end

  deffixture processor_filled(
               processor_empty,
               exit_events,
               contract_exit_statuses,
               in_flight_exit_events,
               contract_ife_statuses
             ) do
    {state, _} = Core.new_exits(processor_empty, exit_events, contract_exit_statuses)
    {state, _} = Core.new_in_flight_exits(state, in_flight_exit_events, contract_ife_statuses)
    state
  end

  deffixture invalid_piggyback_on_input(
               alice,
               processor_filled,
               transactions,
               ife_tx_hashes,
               competing_transactions
             ) do
    tx = hd(transactions)
    competitor = hd(competing_transactions)
    state = processor_filled
    ife_id = hd(ife_tx_hashes)
    txbytes = Transaction.raw_txbytes(tx)
    competitor_txbytes = Transaction.raw_txbytes(competitor)
    recovered = OMG.TestHelper.sign_recover!(tx, [alice.priv, alice.priv])

    %{sigs: competitor_signatures} = DevCrypto.sign(competitor, [alice.priv, alice.priv])

    competitor_ife_event = %{
      call_data: %{in_flight_tx: competitor_txbytes, in_flight_tx_sigs: Enum.join(competitor_signatures)},
      eth_height: 2
    }

    competitor_ife_status = {1, @non_zero_exit_id}

    {state, _} = Core.new_in_flight_exits(state, [competitor_ife_event], [competitor_ife_status])
    {state, _} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 0}])

    {request, state} =
      %ExitProcessor.Request{
        blknum_now: 4000,
        eth_height_now: 5,
        piggybacked_blocks_result: [Block.hashed_txs_at([recovered], 3000)]
      }
      |> Core.find_ifes_in_blocks(state)

    %{
      state: state,
      request: request,
      ife_input_index: 0,
      ife_txbytes: txbytes,
      spending_txbytes: competitor_txbytes,
      spending_input_index: 1,
      spending_sig: hd(competitor_signatures)
    }
  end

  deffixture invalid_piggyback_on_output(
               alice,
               processor_filled,
               transactions,
               ife_tx_hashes
             ) do
    tx = hd(transactions)
    state = processor_filled
    ife_id = hd(ife_tx_hashes)
    # the piggybacked-output-spending tx is going to be included in a block, which requires more back&forth
    # 1. transaction which is, ife'd, output piggybacked, and included in a block
    txbytes = Transaction.raw_txbytes(tx)
    recovered = OMG.TestHelper.sign_recover!(tx, [alice.priv, alice.priv])

    # 2. transaction which spends that piggybacked output
    comp = Transaction.new([{3000, 0, 0}], [])
    comp_txbytes = Transaction.raw_txbytes(comp)
    %{signed_tx: %{sigs: comp_signatures}} = comp_recovered = OMG.TestHelper.sign_recover!(comp, [alice.priv])

    # 3. stuff happens in the contract; output #4 is a double-spend; #5 is OK
    {state, _} =
      Core.new_piggybacks(state, [
        %{tx_hash: ife_id, output_index: 4},
        %{tx_hash: ife_id, output_index: 5}
      ])

    tx_blknum = 3000
    comp_blknum = 4000

    block = Block.hashed_txs_at([recovered], tx_blknum)

    {exit_processor_request, state} =
      %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [block],
        piggybacked_blocks_result: [
          block,
          Block.hashed_txs_at([comp_recovered], comp_blknum)
        ]
      }
      |> Core.find_ifes_in_blocks(state)

    %{
      state: state,
      request: exit_processor_request,
      ife_good_pb_index: 5,
      ife_txbytes: txbytes,
      ife_output_pos: Utxo.position(tx_blknum, 0, 0),
      ife_proof: Block.inclusion_proof(block, 0),
      spending_txbytes: comp_txbytes,
      spending_input_index: 0,
      spending_sig: hd(comp_signatures),
      ife_input_index: 4
    }
  end

  @tag fixtures: [:processor_empty, :exit_events, :contract_exit_statuses]
  test "can start new standard exits one by one or batched", %{
    processor_empty: empty,
    exit_events: events,
    contract_exit_statuses: contract_statuses
  } do
    {state2, _} = Core.new_exits(empty, Enum.slice(events, 0, 1), Enum.slice(contract_statuses, 0, 1))
    {final_state, _} = Core.new_exits(empty, events, contract_statuses)
    assert {^final_state, _} = Core.new_exits(state2, Enum.slice(events, 1, 1), Enum.slice(contract_statuses, 1, 1))
  end

  @tag fixtures: [:processor_empty, :alice, :exit_events]
  test "new_exits sanity checks",
       %{processor_empty: processor, alice: %{addr: alice}, exit_events: [one_exit | _]} do
    {:error, :unexpected_events} = processor |> Core.new_exits([one_exit], [])
    {:error, :unexpected_events} = processor |> Core.new_exits([], [{alice, @eth, 10}])
  end

  @tag fixtures: [:processor_empty, :processor_filled]
  test "can process empty new exits, empty in flight exits or empty finalizations", %{
    processor_empty: empty,
    processor_filled: filled
  } do
    assert {^empty, []} = Core.new_exits(empty, [], [])
    assert {^empty, []} = Core.new_in_flight_exits(empty, [], [])
    assert {^filled, []} = Core.new_exits(filled, [], [])
    assert {^filled, []} = Core.new_in_flight_exits(filled, [], [])
    assert {^filled, [], []} = Core.finalize_exits(filled, {[], []})
  end

  @tag fixtures: [:processor_empty, :alice, :state_empty, :exit_events, :contract_exit_statuses]
  test "handles invalid exit finalization - doesn't forget and causes a byzantine chain report", %{
    processor_empty: processor,
    state_empty: state,
    exit_events: events,
    contract_exit_statuses: contract_exit_statuses
  } do
    {processor, _} =
      processor
      |> Core.new_exits(events, contract_exit_statuses)

    # exits invalidly finalize and continue/start emitting events and complain
    {:ok, {_, two_spend}, state_after_spend} =
      [@utxo_pos1, @utxo_pos2] |> prepare_exit_finalizations() |> State.Core.exit_utxos(state)

    # finalizing here - note that without `finalize_exits`, we would just get a single invalid exit event
    # with - we get 3, because we include the invalidly finalized on which will hurt forever
    # (see persistence tests for the "forever" part)
    assert {processor, [], _} = Core.finalize_exits(processor, two_spend)

    assert {{:error, :unchallenged_exit}, [_event1, _event2, _event3]} =
             %ExitProcessor.Request{eth_height_now: 12, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state_after_spend)
             |> Core.invalid_exits(processor)
  end

  @tag fixtures: [:processor_empty, :state_empty, :exit_events, :contract_exit_statuses, :alice]
  test "can work with State to determine valid exits and finalize them", %{
    processor_empty: processor,
    state_empty: state_empty,
    exit_events: [one_exit | _],
    contract_exit_statuses: [one_status | _],
    alice: alice
  } do
    state = state_empty |> TestHelper.do_deposit(alice, %{amount: 10, currency: @eth, blknum: 2})

    {processor, _} =
      processor
      |> Core.new_exits([one_exit], [one_status])

    assert {:ok, []} =
             %ExitProcessor.Request{eth_height_now: 5, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.invalid_exits(processor)

    # go into the future - old exits work the same
    assert {:ok, []} =
             %ExitProcessor.Request{eth_height_now: 105, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.invalid_exits(processor)

    # exit validly finalizes and continues to not emit any events
    {:ok, {_, spends}, _} = [@utxo_pos1] |> prepare_exit_finalizations() |> State.Core.exit_utxos(state)
    assert {processor, _, [{:delete, :exit_info, {2, 0, 0}}]} = Core.finalize_exits(processor, spends)

    assert %ExitProcessor.Request{utxos_to_check: []} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)
  end

  @tag fixtures: [:processor_empty, :exit_events, :contract_exit_statuses, :alice]
  test "emits exit events when finalizing valid exits", %{
    processor_empty: processor,
    exit_events: [one_exit | _],
    contract_exit_statuses: [one_status | _],
    alice: %{addr: alice_addr}
  } do
    {processor, _} = processor |> Core.new_exits([one_exit], [one_status])

    assert {_, [%{exit_finalized: %{amount: 1, currency: @eth, owner: ^alice_addr, utxo_pos: @utxo_pos1}}], _} =
             Core.finalize_exits(processor, {[@utxo_pos1], []})
  end

  @tag fixtures: [:processor_empty, :exit_events, :contract_exit_statuses]
  test "doesn't emit exit events when finalizing invalid exits", %{
    processor_empty: processor,
    exit_events: [one_exit | _],
    contract_exit_statuses: [one_status | _]
  } do
    {processor, _} = processor |> Core.new_exits([one_exit], [one_status])
    assert {_, [], _} = Core.finalize_exits(processor, {[], [@utxo_pos1]})
  end

  @tag fixtures: [:processor_empty, :state_empty, :exit_events, :contract_exit_statuses]
  test "can work with State to determine and notify invalid exits", %{
    processor_empty: processor,
    state_empty: state,
    exit_events: [one_exit | _],
    contract_exit_statuses: [one_status | _]
  } do
    exiting_position = Utxo.Position.encode(@utxo_pos1)

    {processor, _} =
      processor
      |> Core.new_exits([one_exit], [one_status])

    assert {:ok, [%Event.InvalidExit{utxo_pos: ^exiting_position}]} =
             %ExitProcessor.Request{eth_height_now: 5, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.invalid_exits(processor)
  end

  @tag fixtures: [:processor_empty, :exit_events, :contract_exit_statuses]
  test "can challenge exits, which are then forgotten completely", %{
    processor_empty: processor,
    exit_events: events,
    contract_exit_statuses: contract_statuses
  } do
    {processor, _} =
      processor
      |> Core.new_exits(events, contract_statuses)

    # sanity
    assert %ExitProcessor.Request{utxos_to_check: [_, _]} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)

    assert {processor, _} =
             processor
             |> Core.challenge_exits([
               %{utxo_pos: Utxo.Position.encode(@utxo_pos1)},
               %{utxo_pos: Utxo.Position.encode(@utxo_pos2)}
             ])

    assert %ExitProcessor.Request{utxos_to_check: []} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)
  end

  @tag fixtures: [:processor_empty, :exit_events, :contract_exit_statuses]
  test "can process challenged exits",
       %{processor_empty: processor, exit_events: events} do
    # see the contract and `Eth.RootChain.get_standard_exit/1` for some explanation why like this
    # this is what an exit looks like after a challenge
    zero_status = {0, 0, 0, 0}
    {processor, _} = processor |> Core.new_exits(events, [zero_status, zero_status])

    # sanity
    assert %ExitProcessor.Request{utxos_to_check: [_, _]} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)

    assert {processor, _} =
             processor
             |> Core.challenge_exits([
               %{utxo_pos: Utxo.Position.encode(@utxo_pos1)},
               %{utxo_pos: Utxo.Position.encode(@utxo_pos2)}
             ])

    assert %ExitProcessor.Request{utxos_to_check: []} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)
  end

  @tag fixtures: [:processor_empty, :state_empty, :exit_events, :contract_exit_statuses]
  test "can work with State to determine invalid exits entered too late", %{
    processor_empty: processor,
    state_empty: state,
    exit_events: [one_exit | _],
    contract_exit_statuses: [one_status | _]
  } do
    exiting_position = Utxo.Position.encode(@utxo_pos1)

    {processor, _} =
      processor
      |> Core.new_exits([one_exit], [one_status])

    assert {{:error, :unchallenged_exit},
            [%Event.UnchallengedExit{utxo_pos: ^exiting_position}, %Event.InvalidExit{utxo_pos: ^exiting_position}]} =
             %ExitProcessor.Request{eth_height_now: 13, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.invalid_exits(processor)
  end

  @tag fixtures: [:processor_empty, :state_empty, :exit_events]
  test "invalid exits that have been witnessed already inactive don't excite events", %{
    processor_empty: processor,
    state_empty: state,
    exit_events: [one_exit | _]
  } do
    {processor, _} =
      processor
      |> Core.new_exits([one_exit], [{@zero_address, @eth, 10, Utxo.Position.encode(@utxo_pos1)}])

    assert {:ok, []} =
             %ExitProcessor.Request{eth_height_now: 13, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.invalid_exits(processor)
  end

  @tag fixtures: [:processor_empty, :state_empty, :exit_events, :contract_exit_statuses]
  test "exits of utxos that couldn't have been seen created yet never excite events", %{
    processor_empty: processor,
    state_empty: state,
    exit_events: [_, late_exit | _],
    contract_exit_statuses: [_, active_status | _]
  } do
    {processor, _} =
      processor
      |> Core.new_exits([late_exit], [active_status])

    assert {:ok, []} =
             %ExitProcessor.Request{eth_height_now: 13, blknum_now: @early_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.invalid_exits(processor)
  end

  @tag fixtures: [:processor_empty]
  test "empty processor returns no exiting utxo positions", %{processor_empty: empty} do
    assert %ExitProcessor.Request{utxos_to_check: []} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, empty)
  end

  @tag fixtures: [
         :processor_empty,
         :exit_events,
         :contract_exit_statuses,
         :in_flight_exit_events,
         :contract_ife_statuses
       ]
  test "ifes and standard exits don't interfere", %{
    processor_empty: processor,
    exit_events: [one_exit | _],
    contract_exit_statuses: [one_status | _],
    in_flight_exit_events: [one_ife | _],
    contract_ife_statuses: [one_ife_status | _]
  } do
    {processor, _} = processor |> Core.new_exits([one_exit], [one_status])
    {processor, _} = processor |> Core.new_in_flight_exits([one_ife], [one_ife_status])

    assert %{utxos_to_check: [_, Utxo.position(1, 2, 1), @utxo_pos1]} =
             exit_processor_request =
             %ExitProcessor.Request{eth_height_now: 5, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)

    # here it's crucial that the missing utxo related to the ife isn't interpeted as a standard invalid exit
    # that missing utxo isn't enough for any IFE-related event too
    assert {:ok, [%Event.InvalidExit{}]} =
             exit_processor_request
             |> struct!(utxo_exists_result: [false, false, false])
             |> invalid_exits_filtered(processor, only: [Event.InvalidExit])
  end

  @tag fixtures: [:processor_empty, :in_flight_exit_events, :contract_ife_statuses, :transactions]
  test "properly processes new in flight exits, returns all of them on request", %{
    processor_empty: processor,
    in_flight_exit_events: events,
    contract_ife_statuses: statuses
  } do
    assert [] == Core.get_active_in_flight_exits(processor)

    {processor, _} = Core.new_in_flight_exits(processor, events, statuses)
    ifes_response = Core.get_active_in_flight_exits(processor)

    assert ifes_response |> Enum.count() == 2
  end

  @tag fixtures: [:processor_empty, :in_flight_exit_events, :contract_ife_statuses, :transactions]
  test "correct format of getting all ifes", %{
    processor_empty: processor,
    in_flight_exit_events: events,
    contract_ife_statuses: statuses,
    transactions: [tx1, tx2 | _]
  } do
    {processor, _} = Core.new_in_flight_exits(processor, events, statuses)

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

  @tag fixtures: [:processor_empty, :in_flight_exit_events, :contract_ife_statuses, :transactions]
  test "reports piggybacked inputs/outputs when getting ifes", %{
    processor_empty: processor,
    in_flight_exit_events: [event | _],
    contract_ife_statuses: [status | _],
    transactions: [tx | _]
  } do
    txhash = Transaction.raw_txhash(tx)
    {processor, _} = Core.new_in_flight_exits(processor, [event], [status])
    assert [%{piggybacked_inputs: [], piggybacked_outputs: []}] = Core.get_active_in_flight_exits(processor)

    {processor, _} = Core.new_piggybacks(processor, [%{tx_hash: txhash, output_index: 0}])

    assert [%{piggybacked_inputs: [0], piggybacked_outputs: []}] = Core.get_active_in_flight_exits(processor)

    {processor, _} =
      Core.new_piggybacks(processor, [%{tx_hash: txhash, output_index: 4}, %{tx_hash: txhash, output_index: 5}])

    assert [%{piggybacked_inputs: [0], piggybacked_outputs: [0, 1]}] = Core.get_active_in_flight_exits(processor)
  end

  @tag fixtures: [:processor_empty, :in_flight_exit_events, :contract_ife_statuses]
  test "in flight exits sanity checks", %{
    processor_empty: state,
    in_flight_exit_events: events,
    contract_ife_statuses: statuses
  } do
    assert {state, []} == Core.new_in_flight_exits(state, [], [])
    assert {:error, :unexpected_events} == Core.new_in_flight_exits(state, Enum.slice(events, 0, 1), [])
    assert {:error, :unexpected_events} == Core.new_in_flight_exits(state, [], Enum.slice(statuses, 0, 1))
  end

  @tag fixtures: [:processor_filled, :ife_tx_hashes]
  test "piggybacking sanity checks", %{processor_filled: state, ife_tx_hashes: [ife_id | _]} do
    assert {^state, []} = Core.new_piggybacks(state, [])
    catch_error(Core.new_piggybacks(state, [%{tx_hash: 0, output_index: 0}]))
    catch_error(Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 8}]))

    # cannot piggyback twice the same output
    {updated_state, [_]} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 0}])
    catch_error(Core.new_piggybacks(updated_state, [%{tx_hash: ife_id, output_index: 0}]))
  end

  @tag fixtures: [:processor_filled, :in_flight_exits_challenges_events]
  test "challenges don't affect the list of IFEs returned", %{
    processor_filled: processor,
    in_flight_exits_challenges_events: [challenge | _]
  } do
    assert Core.get_active_in_flight_exits(processor) |> Enum.count() == 2
    {processor2, _} = Core.new_ife_challenges(processor, [challenge])
    assert Core.get_active_in_flight_exits(processor2) |> Enum.count() == 2
    # sanity
    assert processor2 != processor
  end

  @tag fixtures: [:processor_filled, :ife_tx_hashes]
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

  @tag fixtures: [:processor_filled, :ife_tx_hashes]
  test "can open and challenge two piggybacks at one call",
       %{processor_filled: processor, ife_tx_hashes: [tx_hash1, tx_hash2]} do
    events = [%{tx_hash: tx_hash1, output_index: 0}, %{tx_hash: tx_hash2, output_index: 0}]

    {processor, _} = Core.new_piggybacks(processor, events)
    # sanity: there are some piggybacks after piggybacking, to be removed later
    assert [%{piggybacked_inputs: [_]}, %{piggybacked_inputs: [_]}] = Core.get_active_in_flight_exits(processor)
    {processor, _} = Core.challenge_piggybacks(processor, events)

    assert [%{piggybacked_inputs: []}, %{piggybacked_inputs: []}] = Core.get_active_in_flight_exits(processor)
  end

  @tag fixtures: [:processor_filled, :ife_tx_hashes]
  test "challenge piggybacks sanity checks", %{processor_filled: state, ife_tx_hashes: [tx_hash | _]} do
    # cannot challenge piggyback of unknown ife
    assert {state, []} == Core.challenge_piggybacks(state, [%{tx_hash: 0, output_index: 0}])
    # cannot challenge not piggybacked output
    assert {state, []} == Core.challenge_piggybacks(state, [%{tx_hash: tx_hash, output_index: 0}])
    # other sanity checks
    assert {state, []} == Core.challenge_piggybacks(state, [%{tx_hash: tx_hash, output_index: 8}])
  end

  @tag fixtures: [:processor_empty, :alice, :exit_events, :contract_exit_statuses]
  test "detect invalid standard exit based on ife tx which spends same input", %{
    processor_empty: processor,
    alice: alice,
    exit_events: [one_exit | _],
    contract_exit_statuses: [one_status | _]
  } do
    tx = Transaction.new([{2, 0, 0}], [])
    txbytes = Transaction.raw_txbytes(tx)
    signature = DevCrypto.sign(tx, [alice.priv]) |> Map.get(:sigs) |> Enum.join()

    ife_event = %{call_data: %{in_flight_tx: txbytes, in_flight_tx_sigs: signature}, eth_height: 2}
    ife_status = {1, @non_zero_exit_id}

    {processor, _} = Core.new_in_flight_exits(processor, [ife_event], [ife_status])

    {processor, _} =
      processor
      |> Core.new_exits([one_exit], [one_status])

    exiting_utxo = Utxo.Position.encode(@utxo_pos1)

    assert {:ok, [%Event.InvalidExit{utxo_pos: ^exiting_utxo}]} =
             %ExitProcessor.Request{eth_height_now: 5, blknum_now: @late_blknum}
             |> invalid_exits_filtered(processor, only: [Event.InvalidExit])
  end

  describe "available piggybacks" do
    @tag fixtures: [:processor_filled, :transactions, :alice]
    test "detects multiple available piggybacks, with all the fields",
         %{
           processor_filled: processor,
           transactions: [tx1, tx2],
           alice: alice
         } do
      [%{owner: tx1_owner1}, %{owner: tx1_owner2} | _] = Transaction.get_outputs(tx1)
      [%{owner: tx2_owner1}, %{owner: tx2_owner2} | _] = Transaction.get_outputs(tx2)

      txbytes_1 = Transaction.raw_txbytes(tx1)
      txbytes_2 = Transaction.raw_txbytes(tx2)

      assert {:ok, events} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.invalid_exits(processor)

      assert_events(events, [
        %Event.PiggybackAvailable{
          available_inputs: [%{address: alice.addr, index: 0}, %{address: alice.addr, index: 1}],
          available_outputs: [%{address: tx1_owner1, index: 0}, %{address: tx1_owner2, index: 1}],
          txbytes: txbytes_1
        },
        %Event.PiggybackAvailable{
          available_inputs: [%{address: alice.addr, index: 0}, %{address: alice.addr, index: 1}],
          available_outputs: [%{address: tx2_owner1, index: 0}, %{address: tx2_owner2, index: 1}],
          txbytes: txbytes_2
        }
      ])
    end

    @tag fixtures: [:processor_empty, :alice]
    test "detects available piggyback because tx not seen in valid block, regardless of competitors",
         %{processor_empty: processor, alice: alice} do
      # testing this because everywhere else, the test fixtures always imply competitors
      tx = Transaction.new([{1, 0, 0}], [])
      txbytes = Transaction.raw_txbytes(tx)
      signature = DevCrypto.sign(tx, [alice.priv]) |> Map.get(:sigs) |> Enum.join()

      ife_event = %{call_data: %{in_flight_tx: txbytes, in_flight_tx_sigs: signature}, eth_height: 2}
      ife_status = {1, @non_zero_exit_id}

      {processor, _} = Core.new_in_flight_exits(processor, [ife_event], [ife_status])

      assert {:ok, [%Event.PiggybackAvailable{txbytes: ^txbytes}]} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.invalid_exits(processor)
    end

    @tag fixtures: [:processor_empty, :alice]
    test "detects available piggyback correctly, even if signed multiple times",
         %{processor_empty: processor, alice: alice} do
      # there is leeway in the contract, that allows IFE transactions to hold non-zero signatures for zero-inputs
      # we want to be sure that this doesn't crash the `ExitProcessor`
      tx = Transaction.new([{1, 0, 0}], [])
      txbytes = Transaction.raw_txbytes(tx)
      signature = DevCrypto.sign(tx, [alice.priv, alice.priv, alice.priv, alice.priv]) |> Map.get(:sigs) |> Enum.join()

      ife_event = %{call_data: %{in_flight_tx: txbytes, in_flight_tx_sigs: signature}, eth_height: 2}
      ife_status = {1, @non_zero_exit_id}

      {processor, _} = Core.new_in_flight_exits(processor, [ife_event], [ife_status])

      assert {:ok, [%Event.PiggybackAvailable{txbytes: ^txbytes}]} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.invalid_exits(processor)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions]
    test "doesn't detect available piggybacks because txs seen in valid block", %{
      alice: alice,
      processor_filled: processor,
      transactions: [tx1, tx2]
    } do
      recovered_tx1 = OMG.TestHelper.sign_recover!(tx1, [alice.priv, alice.priv])

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([recovered_tx1], 3000)]
      }

      txbytes_2 = Transaction.raw_txbytes(tx2)

      assert {:ok,
              [
                %Event.PiggybackAvailable{
                  txbytes: ^txbytes_2
                }
              ]} = exit_processor_request |> Core.invalid_exits(processor)
    end

    @tag fixtures: [:alice, :bob, :processor_empty]
    test "transaction without outputs and different input owners", %{
      alice: alice,
      bob: bob,
      processor_empty: processor
    } do
      tx = Transaction.new([{1, 0, 0}, {1, 2, 1}], [])

      alice_addr = alice.addr
      bob_addr = bob.addr

      txbytes = Transaction.raw_txbytes(tx)
      signature = DevCrypto.sign(tx, [alice.priv, bob.priv]) |> Map.get(:sigs) |> Enum.join()

      ife_event = %{call_data: %{in_flight_tx: txbytes, in_flight_tx_sigs: signature}, eth_height: 2}
      ife_status = {1, @non_zero_exit_id}

      {processor, _} = Core.new_in_flight_exits(processor, [ife_event], [ife_status])

      assert {:ok,
              [
                %Event.PiggybackAvailable{
                  available_inputs: [%{address: ^alice_addr, index: 0}, %{address: ^bob_addr, index: 1}],
                  available_outputs: [],
                  txbytes: ^txbytes
                }
              ]} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> invalid_exits_filtered(processor, only: [Event.PiggybackAvailable])
    end

    @tag fixtures: [:alice, :processor_empty]
    test "when output is already piggybacked, it is not reported in piggyback available event", %{
      alice: alice,
      processor_empty: processor
    } do
      tx = Transaction.new([{1, 0, 0}, {1, 2, 1}], [])

      txbytes = Transaction.raw_txbytes(tx)
      signature = DevCrypto.sign(tx, [alice.priv, alice.priv]) |> Map.get(:sigs) |> Enum.join()

      ife_event = %{call_data: %{in_flight_tx: txbytes, in_flight_tx_sigs: signature}, eth_height: 2}
      ife_status = {1, @non_zero_exit_id}

      {processor, _} = Core.new_in_flight_exits(processor, [ife_event], [ife_status])

      tx_hash = Transaction.raw_txhash(tx)
      {processor, _} = Core.new_piggybacks(processor, [%{tx_hash: tx_hash, output_index: 0}])

      assert {:ok,
              [
                %Event.PiggybackAvailable{
                  available_inputs: [%{index: 1}],
                  available_outputs: []
                }
              ]} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> invalid_exits_filtered(processor, only: [Event.PiggybackAvailable])
    end

    @tag fixtures: [:alice, :processor_empty]
    test "when ife is finalized, it's outputs are not reported as available for piggyback", %{
      alice: alice,
      processor_empty: processor
    } do
      tx = Transaction.new([{1, 0, 0}, {1, 2, 1}], [])

      txbytes = Transaction.raw_txbytes(tx)
      signature = DevCrypto.sign(tx, [alice.priv, alice.priv]) |> Map.get(:sigs) |> Enum.join()

      ife_event = %{call_data: %{in_flight_tx: txbytes, in_flight_tx_sigs: signature}, eth_height: 2}
      ife_status = {1, @non_zero_exit_id}

      {processor, _} = Core.new_in_flight_exits(processor, [ife_event], [ife_status])

      tx_hash = Transaction.raw_txhash(tx)
      {processor, _} = Core.new_piggybacks(processor, [%{tx_hash: tx_hash, output_index: 0}])

      finalization = %{in_flight_exit_id: @non_zero_exit_id, output_index: 0}

      {:ok, processor, _} = Core.finalize_in_flight_exits(processor, [finalization])

      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> invalid_exits_filtered(processor, only: [Event.PiggybackAvailable])
    end

    @tag fixtures: [:processor_filled, :transactions, :in_flight_exits_challenges_events]
    test "challenged IFEs emit the same piggybacks as canonical ones", %{
      processor_filled: processor,
      in_flight_exits_challenges_events: [challenge_event | _]
    } do
      assert {:ok, events_canonical} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> Core.invalid_exits(processor)

      {challenged_processor, _} = Core.new_ife_challenges(processor, [challenge_event])

      assert {:ok, events_challenged} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.invalid_exits(challenged_processor)

      assert_events(events_canonical, events_challenged)
    end
  end

  describe "evaluates correctness of new piggybacks" do
    @tag fixtures: [:alice, :processor_filled, :transactions, :ife_tx_hashes, :competing_transactions]
    test "detects double-spend of an input, found in IFE",
         %{
           alice: alice,
           processor_filled: state,
           transactions: [tx | _],
           competing_transactions: [comp | _],
           ife_tx_hashes: [ife_id | _]
         } do
      txbytes = Transaction.raw_txbytes(tx)
      comp_txbytes = Transaction.raw_txbytes(comp)

      %{sigs: [first_sig, other_sig]} = DevCrypto.sign(comp, [alice.priv, alice.priv])

      other_ife_event = %{
        call_data: %{in_flight_tx: comp_txbytes, in_flight_tx_sigs: first_sig <> other_sig},
        eth_height: 3
      }

      other_ife_status = {1, @non_zero_exit_id}

      {state, _} = Core.new_in_flight_exits(state, [other_ife_event], [other_ife_status])

      {state, _} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 0}])
      request = %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}

      assert {:ok, [%Event.InvalidPiggyback{txbytes: ^txbytes, inputs: [0], outputs: []}]} =
               invalid_exits_filtered(request, state, only: [Event.InvalidPiggyback])

      assert {:ok,
              %{
                in_flight_input_index: 0,
                in_flight_txbytes: ^txbytes,
                spending_txbytes: ^comp_txbytes,
                spending_input_index: 1,
                spending_sig: ^other_sig
              }} = Core.get_input_challenge_data(request, state, txbytes, 0)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions, :ife_tx_hashes, :competing_transactions]
    test "detects double-spend of an input, found in a block",
         %{
           alice: alice,
           processor_filled: state,
           transactions: [tx | _],
           competing_transactions: [comp | _],
           ife_tx_hashes: [ife_id | _]
         } do
      txbytes = Transaction.raw_txbytes(tx)
      comp_txbytes = Transaction.raw_txbytes(comp)

      %{signed_tx: %{sigs: [_, other_sig]}} =
        comp_recovered = OMG.TestHelper.sign_recover!(comp, [alice.priv, alice.priv])

      {state, _} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 0}])

      comp_blknum = 4000

      {request, state} =
        %ExitProcessor.Request{
          blknum_now: 5000,
          eth_height_now: 5,
          blocks_result: [Block.hashed_txs_at([comp_recovered], comp_blknum)]
        }
        |> Core.find_ifes_in_blocks(state)

      assert {:ok, [%Event.InvalidPiggyback{txbytes: ^txbytes, inputs: [0], outputs: []}]} =
               invalid_exits_filtered(request, state, only: [Event.InvalidPiggyback])

      assert {:ok,
              %{
                in_flight_input_index: 0,
                in_flight_txbytes: ^txbytes,
                spending_txbytes: ^comp_txbytes,
                spending_input_index: 1,
                spending_sig: ^other_sig
              }} = Core.get_input_challenge_data(request, state, txbytes, 0)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions, :ife_tx_hashes, :competing_transactions]
    test "detects double-spend of an output, found in a IFE",
         %{
           alice: alice,
           processor_filled: state,
           transactions: [tx | _],
           ife_tx_hashes: [ife_id | _]
         } do
      # 1. transaction which is, ife'd, output piggybacked, and included in a block
      txbytes = Transaction.raw_txbytes(tx)
      recovered = OMG.TestHelper.sign_recover!(tx, [alice.priv, alice.priv])
      tx_blknum = 3000

      # 2. transaction which spends that piggybacked output
      comp = Transaction.new([{tx_blknum, 0, 0}], [])
      comp_txbytes = Transaction.raw_txbytes(comp)
      %{sigs: [comp_signature]} = DevCrypto.sign(comp, [alice.priv])

      other_ife_event = %{
        call_data: %{in_flight_tx: comp_txbytes, in_flight_tx_sigs: comp_signature},
        eth_height: 4
      }

      other_ife_status = {1, @non_zero_exit_id}

      # 3. stuff happens in the contract
      {state, _} = Core.new_in_flight_exits(state, [other_ife_event], [other_ife_status])
      {state, _} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 4}])

      {exit_processor_request, state} =
        %ExitProcessor.Request{
          blknum_now: 5000,
          eth_height_now: 5,
          piggybacked_blocks_result: [Block.hashed_txs_at([recovered], tx_blknum)]
        }
        |> Core.find_ifes_in_blocks(state)

      assert {:ok, [%Event.InvalidPiggyback{txbytes: ^txbytes, inputs: [], outputs: [0]}]} =
               invalid_exits_filtered(exit_processor_request, state, only: [Event.InvalidPiggyback])

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

    @tag fixtures: [:alice, :processor_filled, :transactions, :ife_tx_hashes, :competing_transactions]
    test "detects double-spend of an output, found in a block",
         %{
           alice: alice,
           processor_filled: state,
           transactions: [tx | _],
           ife_tx_hashes: [ife_id | _]
         } do
      # this time, the piggybacked-output-spending tx is going to be included in a block, which requires more back&forth
      # 1. transaction which is, ife'd, output piggybacked, and included in a block
      txbytes = Transaction.raw_txbytes(tx)
      recovered = OMG.TestHelper.sign_recover!(tx, [alice.priv, alice.priv])
      tx_blknum = 3000

      # 2. transaction which spends that piggybacked output
      comp = Transaction.new([{tx_blknum, 0, 0}], [])
      comp_txbytes = Transaction.raw_txbytes(comp)
      %{signed_tx: %{sigs: [comp_signature]}} = comp_recovered = OMG.TestHelper.sign_recover!(comp, [alice.priv])

      # 3. stuff happens in the contract
      {state, _} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 4}])

      comp_blknum = 4000

      {exit_processor_request, state} =
        %ExitProcessor.Request{
          blknum_now: 5000,
          eth_height_now: 5,
          piggybacked_blocks_result: [
            Block.hashed_txs_at([recovered], tx_blknum)
          ]
        }
        |> Core.find_ifes_in_blocks(state)

      exit_processor_request = %{
        exit_processor_request
        | blocks_result: [Block.hashed_txs_at([comp_recovered], comp_blknum)]
      }

      assert {:ok, [%Event.InvalidPiggyback{txbytes: ^txbytes, inputs: [], outputs: [0]}]} =
               invalid_exits_filtered(exit_processor_request, state, only: [Event.InvalidPiggyback])

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

    @tag fixtures: [:alice, :processor_filled, :transactions, :ife_tx_hashes, :competing_transactions]
    test "does not look into piggybacked_blocks_result when it should not",
         %{
           alice: alice,
           processor_filled: state,
           transactions: [tx | _],
           ife_tx_hashes: [ife_id | _]
         } do
      recovered = OMG.TestHelper.sign_recover!(tx, [alice.priv, alice.priv])
      txbytes = Transaction.raw_txbytes(tx)
      tx_blknum = 3000

      {state, _} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 4}])

      {exit_processor_request, state} =
        %ExitProcessor.Request{
          blknum_now: 5000,
          eth_height_now: 5,
          piggybacked_blocks_result: [
            Block.hashed_txs_at([recovered], tx_blknum)
          ]
        }
        |> Core.find_ifes_in_blocks(state)

      exit_processor_request = %{
        exit_processor_request
        | blocks_result: [],
          piggybacked_blocks_result: nil
      }

      assert {:ok, []} = invalid_exits_filtered(exit_processor_request, state, only: [Event.InvalidPiggyback])

      assert {:error, :no_double_spend_on_particular_piggyback} =
               Core.get_output_challenge_data(exit_processor_request, state, txbytes, 0)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions, :ife_tx_hashes, :competing_transactions]
    test "handles well situation when syncing is in progress",
         %{
           processor_filled: state,
           ife_tx_hashes: [ife_id | _]
         } do
      {state, _} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 4}])

      assert %ExitProcessor.Request{utxos_to_check: [], piggybacked_utxos_to_check: []} =
               %ExitProcessor.Request{eth_height_now: 13, blknum_now: 0}
               |> Core.determine_ife_input_utxos_existence_to_get(state)
               |> Core.determine_utxo_existence_to_get(state)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions, :ife_tx_hashes, :competing_transactions]
    test "seeks piggybacked-output-spending txs in blocks",
         %{
           alice: alice,
           processor_filled: processor,
           transactions: [tx | _],
           ife_tx_hashes: [ife_id | _]
         } do
      # if an output-piggybacking transaction is included in some block, we need to seek blocks that could be spending
      recovered = tx |> OMG.TestHelper.sign_recover!([alice.priv, alice.priv])

      {processor, _} = Core.new_piggybacks(processor, [%{tx_hash: ife_id, output_index: 4}])

      tx_blknum = 3000

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([recovered], tx_blknum)]
      }

      # for one piggybacked output, we're asking for its inputs positions to check utxo existence
      request = Core.determine_ife_input_utxos_existence_to_get(exit_processor_request, processor)
      assert Utxo.position(1, 0, 0) in request.piggybacked_utxos_to_check
      assert Utxo.position(1, 2, 1) in request.piggybacked_utxos_to_check

      # if it turns out to not exists, we're fetching the spending block
      request =
        exit_processor_request
        |> struct!(%{piggybacked_utxos_to_check: [Utxo.position(1, 0, 0)], piggybacked_utxo_exists_result: [false]})
        |> Core.determine_ife_spends_to_get(processor)

      assert Utxo.position(1, 0, 0) in request.piggybacked_spends_to_get

      assert %ExitProcessor.Request{piggybacked_blknums_to_get: [1]} =
               exit_processor_request
               |> struct!(%{piggybacked_spends_to_get: [Utxo.position(1, 0, 0)], piggybacked_spent_blknum_result: [1]})
               |> Core.determine_ife_blocks_to_get()
    end

    @tag fixtures: [:alice, :carol, :processor_filled, :transactions, :ife_tx_hashes]
    test "detects multiple double-spends in single IFE",
         %{
           alice: alice,
           carol: carol,
           processor_filled: state,
           transactions: [tx | _],
           ife_tx_hashes: [ife_id | _]
         } do
      tx_blknum = 3000
      txbytes = Transaction.raw_txbytes(tx)
      recovered = OMG.TestHelper.sign_recover!(tx, [alice.priv, alice.priv])

      comp = Transaction.new([{1, 0, 0}, {1, 2, 1}, {tx_blknum, 0, 0}, {tx_blknum, 0, 1}], [])
      comp_txbytes = Transaction.raw_txbytes(comp)
      %{sigs: [_, alice_sig | _] = array_of_sigs} = DevCrypto.sign(tx, [alice.priv, alice.priv, alice.priv, carol.priv])

      other_ife_event = %{
        call_data: %{in_flight_tx: comp_txbytes, in_flight_tx_sigs: Enum.join(array_of_sigs)},
        eth_height: 2
      }

      other_ife_status = {1, @non_zero_exit_id}

      {state, _} = Core.new_in_flight_exits(state, [other_ife_event], [other_ife_status])

      {state, _} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 0}])
      {state, _} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 1}])
      {state, _} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 4}])
      {state, _} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 5}])

      {request, state} =
        %ExitProcessor.Request{
          blknum_now: 4000,
          eth_height_now: 5,
          piggybacked_blocks_result: [Block.hashed_txs_at([recovered], tx_blknum)]
        }
        |> Core.find_ifes_in_blocks(state)

      assert {:ok, [%Event.InvalidPiggyback{txbytes: ^txbytes, inputs: [0, 1], outputs: [0, 1]}]} =
               invalid_exits_filtered(request, state, only: [Event.InvalidPiggyback])

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
    @tag fixtures: [:invalid_piggyback_on_input, :competing_transactions]
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

    @tag fixtures: [:invalid_piggyback_on_input, :competing_transactions]
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

    @tag fixtures: [:invalid_piggyback_on_input, :competing_transactions]
    test "fail when asked to produce proof for wrong txhash",
         %{invalid_piggyback_on_input: %{state: state, request: request}, competing_transactions: [_, _, comp3 | _]} do
      comp3_txbytes = Transaction.raw_txbytes(comp3)
      assert {:error, :unknown_ife} = Core.get_input_challenge_data(request, state, comp3_txbytes, 0)
    end

    @tag fixtures: [:invalid_piggyback_on_input, :competing_transactions]
    test "fail when asked to produce proof for wrong badly encoded tx",
         %{invalid_piggyback_on_input: %{state: state, request: request}, competing_transactions: [_, _, comp3 | _]} do
      corrupted_txbytes = "corruption" <> Transaction.raw_txbytes(comp3)
      assert {:error, :malformed_transaction_rlp} = Core.get_input_challenge_data(request, state, corrupted_txbytes, 0)
    end

    @tag fixtures: [:invalid_piggyback_on_input]
    test "fail when asked to produce proof for illegal oindex",
         %{invalid_piggyback_on_input: %{state: state, request: request, ife_txbytes: txbytes}} do
      assert {:error, :piggybacked_index_out_of_range} = Core.get_input_challenge_data(request, state, txbytes, -1)
    end

    @tag fixtures: [:invalid_piggyback_on_output]
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

    @tag fixtures: [:invalid_piggyback_on_output]
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
    @tag fixtures: [:processor_filled]
    test "none if input never spent elsewhere",
         %{processor_filled: processor} do
      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> invalid_exits_filtered(processor, exclude: [Event.PiggybackAvailable])
    end

    @tag fixtures: [:processor_filled, :transactions, :competing_transactions, :alice]
    test "none if different input spent in some tx from appendix",
         %{processor_filled: processor, transactions: [tx1 | _], competing_transactions: [_, _, comp3], alice: alice} do
      txbytes = Transaction.raw_txbytes(tx1)

      other_txbytes = Transaction.raw_txbytes(comp3)
      other_signature = DevCrypto.sign(comp3, [alice.priv, alice.priv]) |> Map.get(:sigs) |> Enum.join()

      other_ife_event = %{call_data: %{in_flight_tx: other_txbytes, in_flight_tx_sigs: other_signature}, eth_height: 2}
      other_ife_status = {1, @non_zero_exit_id}

      {processor, _} = Core.new_in_flight_exits(processor, [other_ife_event], [other_ife_status])

      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> invalid_exits_filtered(processor, exclude: [Event.PiggybackAvailable])

      assert {:error, :competitor_not_found} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions, :competing_transactions]
    test "none if different input spent in some tx from block",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _], competing_transactions: [_, _, comp3]} do
      txbytes = Transaction.raw_txbytes(tx1)
      other_recovered = OMG.TestHelper.sign_recover!(comp3, [alice.priv, alice.priv])

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([other_recovered], 3000)]
      }

      assert {:ok, []} =
               exit_processor_request |> invalid_exits_filtered(processor, exclude: [Event.PiggybackAvailable])

      assert {:error, :competitor_not_found} =
               exit_processor_request
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions]
    test "none if input spent in _same_ tx in block",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _]} do
      txbytes = Transaction.raw_txbytes(tx1)
      other_recovered = OMG.TestHelper.sign_recover!(tx1, [alice.priv, alice.priv])

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([other_recovered], 3000)]
      }

      assert {:ok, []} =
               exit_processor_request |> invalid_exits_filtered(processor, exclude: [Event.PiggybackAvailable])

      assert {:error, :competitor_not_found} =
               exit_processor_request
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions]
    test "none if input spent in _same_ tx in tx appendix",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _]} do
      txbytes = Transaction.raw_txbytes(tx1)

      other_txbytes = Transaction.raw_txbytes(tx1)
      %{sigs: [other_signature, _]} = DevCrypto.sign(tx1, [alice.priv, alice.priv])

      other_ife_event = %{call_data: %{in_flight_tx: other_txbytes, in_flight_tx_sigs: other_signature}, eth_height: 2}
      other_ife_status = {1, @non_zero_exit_id}

      {processor, _} = Core.new_in_flight_exits(processor, [other_ife_event], [other_ife_status])

      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> invalid_exits_filtered(processor, exclude: [Event.PiggybackAvailable])

      assert {:error, :competitor_not_found} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions, :competing_transactions]
    test "each other, if input spent in different ife",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _], competing_transactions: [comp | _]} do
      txbytes = Transaction.raw_txbytes(tx1)

      other_txbytes = Transaction.raw_txbytes(comp)
      %{sigs: [other_signature, _]} = DevCrypto.sign(comp, [alice.priv, <<>>])

      other_ife_event = %{call_data: %{in_flight_tx: other_txbytes, in_flight_tx_sigs: other_signature}, eth_height: 2}
      other_ife_status = {1, @non_zero_exit_id}

      {processor, _} = Core.new_in_flight_exits(processor, [other_ife_event], [other_ife_status])

      assert {:ok, events} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> invalid_exits_filtered(processor, only: [Event.NonCanonicalIFE])

      # no invalid piggyback events are generated
      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> invalid_exits_filtered(processor, only: [Event.InvalidPiggyback])

      assert_events(events, [%Event.NonCanonicalIFE{txbytes: txbytes}, %Event.NonCanonicalIFE{txbytes: other_txbytes}])

      assert {:ok,
              %{
                in_flight_txbytes: ^txbytes,
                in_flight_input_index: 0,
                competing_txbytes: ^other_txbytes,
                competing_input_index: 1,
                competing_sig: ^other_signature,
                competing_tx_pos: Utxo.position(0, 0, 0),
                competing_proof: ""
              }} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions]
    test "a competitor that's submitted as challenge to other IFE",
         %{alice: alice, processor_filled: processor, transactions: [tx1, tx2 | _]} do
      # ifes in processor here aren't competitors to each other, but the challenge filed for tx2 is a competitor
      # for tx1, which is what we want to detect:
      competing_tx = Transaction.new([{1, 0, 0}], [])
      %{sigs: [other_signature, _]} = DevCrypto.sign(competing_tx, [alice.priv, <<>>])

      txbytes = Transaction.raw_txbytes(tx1)
      other_txbytes = Transaction.raw_txbytes(competing_tx)

      challenge_event = %{
        tx_hash: Transaction.raw_txhash(tx2),
        competitor_position: not_included_competitor_pos(),
        call_data: %{competing_tx: other_txbytes, competing_tx_input_index: 0, competing_tx_sig: other_signature}
      }

      {processor, _} = Core.new_ife_challenges(processor, [challenge_event])

      exit_processor_request = %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}

      assert {:ok, [%Event.NonCanonicalIFE{txbytes: ^txbytes}]} =
               exit_processor_request |> invalid_exits_filtered(processor, only: [Event.NonCanonicalIFE])

      assert {:ok,
              %{
                in_flight_txbytes: ^txbytes,
                competing_txbytes: ^other_txbytes,
                competing_input_index: 0,
                competing_sig: ^other_signature
              }} = exit_processor_request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions, :competing_transactions]
    test "a single competitor included in a block, with proof",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _], competing_transactions: [comp | _]} do
      txbytes = Transaction.raw_txbytes(tx1)
      other_txbytes = Transaction.raw_txbytes(comp)

      %{signed_tx: %{sigs: [other_signature, _]}} =
        other_recovered = OMG.TestHelper.sign_recover!(comp, [alice.priv, alice.priv])

      other_blknum = 3000

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([other_recovered], other_blknum)]
      }

      assert {:ok, [%Event.NonCanonicalIFE{txbytes: ^txbytes}]} =
               exit_processor_request
               |> invalid_exits_filtered(processor, only: [Event.NonCanonicalIFE])

      assert {:ok,
              %{
                in_flight_txbytes: ^txbytes,
                in_flight_input_index: 0,
                competing_txbytes: ^other_txbytes,
                competing_input_index: 1,
                competing_sig: ^other_signature,
                competing_tx_pos: Utxo.position(^other_blknum, 0, 0),
                competing_proof: proof_bytes
              }} =
               exit_processor_request
               |> Core.get_competitor_for_ife(processor, txbytes)

      assert_proof_sound(proof_bytes)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions, :competing_transactions]
    test "handle two competitors, when the younger one already challenged",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _], competing_transactions: [comp | _]} do
      txbytes = Transaction.raw_txbytes(tx1)
      other_txbytes = Transaction.raw_txbytes(comp)

      %{signed_tx: %{sigs: [other_signature, _]}} =
        other_recovered = OMG.TestHelper.sign_recover!(comp, [alice.priv, alice.priv])

      other_blknum = 3000

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([other_recovered, other_recovered], other_blknum)]
      }

      # the transaction is firstmost submitted as a competitor and used to challenge with no inclusion proof
      other_ife_event = %{call_data: %{in_flight_tx: other_txbytes, in_flight_tx_sigs: other_signature}, eth_height: 2}
      other_ife_status = {1, @non_zero_exit_id}
      {processor, _} = Core.new_in_flight_exits(processor, [other_ife_event], [other_ife_status])

      challenge = %{
        tx_hash: Transaction.raw_txhash(tx1),
        # in-flight transaction
        competitor_position: not_included_competitor_pos(),
        call_data: %{
          competing_tx: other_txbytes,
          competing_tx_input_index: 1,
          competing_tx_sig: @zero_sig
        }
      }

      # sanity check - there's two non-canonicals, because IFE compete with each other
      # after the first challenge there should be only one, after the final challenge - none
      assert {:ok, [_, _]} = exit_processor_request |> invalid_exits_filtered(processor, only: [Event.NonCanonicalIFE])

      assert_competitors_work = fn processor ->
        # should be `assert {:ok, [_, _]}` but we have OMG-441 (see other comment)
        assert {:ok, [_]} = exit_processor_request |> invalid_exits_filtered(processor, only: [Event.NonCanonicalIFE])

        assert {:ok, %{competing_txbytes: ^other_txbytes, competing_tx_pos: Utxo.position(^other_blknum, 0, 0)}} =
                 exit_processor_request |> Core.get_competitor_for_ife(processor, txbytes)
      end

      # challenge with IFE (no position)
      {processor, _} = Core.new_ife_challenges(processor, [challenge])
      assert_competitors_work.(processor)

      # challenge with the younger competitor (incomplete challenge)
      young_challenge = %{challenge | competitor_position: Utxo.position(other_blknum, 1, 0) |> Utxo.Position.encode()}
      {processor, _} = Core.new_ife_challenges(processor, [young_challenge])
      assert_competitors_work.(processor)

      # challenge with the older competitor (final)
      older_challenge = %{challenge | competitor_position: Utxo.position(other_blknum, 0, 0) |> Utxo.Position.encode()}
      {processor, _} = Core.new_ife_challenges(processor, [older_challenge])
      # NOTE: should be like this - only the "other" IFE remains challenged, because our main one got challenged by the
      # oldest competitor now):
      # assert {:ok, [_]} = exit_processor_request |> invalid_exits_filtered(processor, only: [Event.NonCanonicalIFE])?
      #
      # i.e. if the challenge present is no the oldest competitor, we still should challenge. After it is the oldest
      # we stop bothering, see OMG-441
      #
      # this is temporary behavior being tested:
      assert_competitors_work.(processor)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions, :competing_transactions]
    test "none if IFE is challenged enough already",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _], competing_transactions: [comp | _]} do
      txbytes = Transaction.raw_txbytes(tx1)
      other_txbytes = Transaction.raw_txbytes(comp)
      other_recovered = OMG.TestHelper.sign_recover!(comp, [alice.priv, alice.priv])
      other_blknum = 3000

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([other_recovered], other_blknum)]
      }

      challenge_event = %{
        tx_hash: Transaction.raw_txhash(tx1),
        # in-flight transaction
        competitor_position: Utxo.position(other_blknum, 0, 0) |> Utxo.Position.encode(),
        call_data: %{
          competing_tx: other_txbytes,
          competing_tx_input_index: 1,
          competing_tx_sig: @zero_sig
        }
      }

      {processor, _} = Core.new_ife_challenges(processor, [challenge_event])

      assert {:ok, []} = exit_processor_request |> invalid_exits_filtered(processor, only: [Event.NonCanonicalIFE])

      # getting the competitor is still valid, so allowing this
      assert {:ok, %{competing_txbytes: ^other_txbytes, competing_tx_pos: Utxo.position(other_blknum, 0, 0)}} =
               exit_processor_request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions]
    test "a competitor having the double-spend on various input indices",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _]} do
      input_spent_in_idx0 = {1, 0, 0}
      input_spent_in_idx1 = {1, 2, 1}
      other_input1 = {10, 2, 1}
      other_input2 = {11, 2, 1}
      other_input3 = {12, 2, 1}

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

      txbytes = Transaction.raw_txbytes(tx1)

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
                 exit_processor_request |> invalid_exits_filtered(processor, only: [Event.NonCanonicalIFE])

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

    @tag fixtures: [:alice, :bob, :processor_filled, :transactions, :competing_transactions]
    test "a competitor being signed on various positions",
         %{
           alice: alice,
           bob: bob,
           processor_filled: processor,
           transactions: [tx1 | _],
           competing_transactions: [competitor | _]
         } do
      txbytes = Transaction.raw_txbytes(tx1)

      %{signed_tx: %{sigs: [_, other_signature]}} =
        other_recovered = OMG.TestHelper.sign_recover!(competitor, [bob.priv, alice.priv])

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([other_recovered], 3000)]
      }

      assert {:ok, %{competing_sig: ^other_signature}} =
               exit_processor_request
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    @tag fixtures: [:alice, :processor_filled, :transactions, :competing_transactions]
    test "a best competitor, included earliest in a block, regardless of conflicting utxo position",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _], competing_transactions: [comp | _]} do
      # NOTE that the recent competitor spends an __older__ input. Also note the reversing of block results done below
      #      Regardless of these, the best competitor (from blknum 2000) must always be returned
      # NOTE also that non-included competitors always are considered last, and hence worst and never are returned

      # first the included competitors
      comp_recent = Transaction.new([{1, 0, 0}], [])
      comp_oldest = Transaction.new([{1, 2, 1}], [])
      recovered_recent = OMG.TestHelper.sign_recover!(comp_recent, [alice.priv])
      recovered_oldest = OMG.TestHelper.sign_recover!(comp_oldest, [alice.priv])

      # ife-related competitor
      other_ife_event = %{
        call_data: %{in_flight_tx: Transaction.raw_txbytes(comp), in_flight_tx_sigs: <<4::520>>},
        eth_height: 2
      }

      other_ife_status = {1, @non_zero_exit_id}
      {processor, _} = Core.new_in_flight_exits(processor, [other_ife_event], [other_ife_status])

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([recovered_oldest], 2000), Block.hashed_txs_at([recovered_recent], 3000)]
      }

      txbytes = Transaction.raw_txbytes(tx1)

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

    @tag fixtures: [:processor_filled]
    test "by asking for utxo existence concerning active ifes and standard exits",
         %{processor_filled: processor} do
      assert %{
               utxos_to_check: [
                 # refer to stuff added by `deffixture processor_filled` for this - both ifes and standard exits here
                 Utxo.position(1, 0, 0),
                 Utxo.position(1, 2, 1),
                 Utxo.position(2, 0, 0),
                 Utxo.position(2, 1, 0),
                 Utxo.position(2, 2, 1),
                 Utxo.position(9000, 0, 1)
               ]
             } =
               %ExitProcessor.Request{blknum_now: @late_blknum}
               |> Core.determine_utxo_existence_to_get(processor)
    end

    @tag fixtures: [:processor_filled]
    test "by asking for utxo spends concerning active ifes",
         %{processor_filled: processor} do
      assert %{spends_to_get: [Utxo.position(1, 2, 1)]} =
               %ExitProcessor.Request{
                 utxos_to_check: [Utxo.position(1, 2, 1), Utxo.position(112, 2, 1)],
                 utxo_exists_result: [false, false]
               }
               |> Core.determine_spends_to_get(processor)
    end

    @tag fixtures: [:alice, :processor_empty, :transactions]
    test "by not asking for utxo spends concerning non-active ifes",
         %{alice: alice, processor_empty: processor, transactions: [tx | _]} do
      txbytes = Transaction.raw_txbytes(tx)
      %{sigs: [signature, _]} = DevCrypto.sign(tx, [alice.priv, <<>>])

      ife_event = %{call_data: %{in_flight_tx: txbytes, in_flight_tx_sigs: signature}, eth_height: 2}
      # inactive
      ife_status = {0, @non_zero_exit_id}

      {processor, _} = Core.new_in_flight_exits(processor, [ife_event], [ife_status])

      assert %{spends_to_get: []} =
               %ExitProcessor.Request{
                 utxos_to_check: [Utxo.position(1, 0, 0)],
                 utxo_exists_result: [false]
               }
               |> Core.determine_spends_to_get(processor)
    end

    @tag fixtures: [:alice, :processor_empty, :transactions]
    test "by not asking for utxo spends concerning finalized ifes",
         %{alice: alice, processor_empty: processor, transactions: [tx | _]} do
      txbytes = Transaction.raw_txbytes(tx)
      %{sigs: [signature, _]} = DevCrypto.sign(tx, [alice.priv, <<>>])

      ife_event = %{call_data: %{in_flight_tx: txbytes, in_flight_tx_sigs: signature}, eth_height: 2}
      # inactive
      ife_status = {0, @non_zero_exit_id}

      {processor, _} = Core.new_in_flight_exits(processor, [ife_event], [ife_status])

      assert %{spends_to_get: []} =
               %ExitProcessor.Request{
                 utxos_to_check: [Utxo.position(1, 0, 0)],
                 utxo_exists_result: [false]
               }
               |> Core.determine_spends_to_get(processor)
    end

    @tag fixtures: [:processor_empty]
    test "by not asking for spends on no ifes",
         %{processor_empty: processor} do
      assert %{spends_to_get: []} =
               %ExitProcessor.Request{utxos_to_check: [Utxo.position(1, 0, 0)], utxo_exists_result: [false]}
               |> Core.determine_spends_to_get(processor)
    end

    @tag fixtures: [:alice, :processor_filled, :state_empty]
    test "by working with State - only asking for spends concerning ifes",
         %{
           alice: alice,
           processor_filled: processor,
           state_empty: state_empty
         } do
      state = state_empty |> TestHelper.do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      other_recovered = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 8}])

      # first sanity-check as if the utxo was not spent yet
      assert %{utxos_to_check: utxos_to_check, utxo_exists_result: utxo_exists_result, spends_to_get: spends_to_get} =
               %ExitProcessor.Request{blknum_now: @late_blknum}
               |> Core.determine_utxo_existence_to_get(processor)
               |> mock_utxo_exists(state)
               |> Core.determine_spends_to_get(processor)

      assert {Utxo.position(1, 0, 0), false} not in Enum.zip(utxos_to_check, utxo_exists_result)
      assert Utxo.position(1, 0, 0) not in spends_to_get

      # spend and see that Core now requests the relevant utxo checks and spends to get
      {:ok, _, state} = State.Core.exec(state, other_recovered, %{@eth => 0})
      {:ok, {block, _, _}, state} = State.Core.form_block(1000, state)

      assert %{utxos_to_check: utxos_to_check, utxo_exists_result: utxo_exists_result, spends_to_get: spends_to_get} =
               %ExitProcessor.Request{blknum_now: @late_blknum, blocks_result: [block]}
               |> Core.determine_utxo_existence_to_get(processor)
               |> mock_utxo_exists(state)
               |> Core.determine_spends_to_get(processor)

      assert {Utxo.position(1, 0, 0), false} in Enum.zip(utxos_to_check, utxo_exists_result)
      assert Utxo.position(1, 0, 0) in spends_to_get
    end

    test "by asking for the right blocks",
         %{} do
      # NOTE: for now test trivial, because we don't require any filtering yet
      assert %{blknums_to_get: [1000]} =
               %ExitProcessor.Request{spent_blknum_result: [1000]} |> Core.determine_blocks_to_get()

      assert %{blknums_to_get: []} = %ExitProcessor.Request{spent_blknum_result: []} |> Core.determine_blocks_to_get()

      assert %{blknums_to_get: [1000, 2000]} =
               %ExitProcessor.Request{spent_blknum_result: [2000, 1000]} |> Core.determine_blocks_to_get()
    end

    @tag fixtures: [:processor_filled]
    test "none if input not yet created during sync",
         %{processor_filled: processor} do
      assert %{utxos_to_check: to_check} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 13}
               |> Core.determine_utxo_existence_to_get(processor)

      assert Utxo.position(9000, 0, 1) not in to_check
    end

    @tag fixtures: [:transactions, :processor_empty]
    test "for nonexistent tx doesn't crash",
         %{transactions: [tx | _], processor_empty: processor} do
      txbytes = Transaction.raw_txbytes(tx)

      assert {:error, :ife_not_known_for_tx} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, txbytes)
    end
  end

  describe "detects the need and allows to respond to canonicity challenges" do
    @tag fixtures: [:alice, :processor_filled, :transactions, :in_flight_exits_challenges_events]
    test "against a competitor",
         %{
           alice: alice,
           processor_filled: processor,
           transactions: [tx1 | _] = txs,
           in_flight_exits_challenges_events: [challenge_event | _]
         } do
      {challenged_processor, _} = Core.new_ife_challenges(processor, [challenge_event])
      txbytes = Transaction.raw_txbytes(tx1)

      other_blknum = 3000

      block =
        txs
        |> Enum.map(&OMG.TestHelper.sign_recover!(&1, [alice.priv, alice.priv]))
        |> Block.hashed_txs_at(other_blknum)

      other_blknum = 3000

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [block]
      }

      assert {:ok, [%Event.InvalidIFEChallenge{txbytes: ^txbytes}]} =
               exit_processor_request |> Core.invalid_exits(challenged_processor)

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

    @tag fixtures: [:transactions]
    test "proving canonical for nonexistent tx doesn't crash",
         %{transactions: [tx | _]} do
      txbytes = Transaction.raw_txbytes(tx)

      assert {:error, :canonical_not_found} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.prove_canonical_for_ife(txbytes)
    end

    @tag fixtures: [:processor_filled]
    test "none if ifes are canonical",
         %{processor_filled: processor} do
      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> invalid_exits_filtered(processor, exclude: [Event.PiggybackAvailable])
    end

    # TODO: implement more behavior tests
    test "none if challenge gets responded and ife canonical",
         %{} do
    end
  end

  describe "in-flight exit finalization" do
    @tag fixtures: [:processor_empty, :in_flight_exit_events, :contract_ife_statuses]
    test "deactivate in-flight exit after all piggybacked outputs are finalized",
         %{
           processor_empty: processor,
           in_flight_exit_events: [ife | _],
           contract_ife_statuses: [{_, ife_id} = ife_status | _]
         } do
      {processor, _} = Core.new_in_flight_exits(processor, [ife], [ife_status])
      tx_hash = ife_tx_hash(ife)

      {processor, _} = Core.new_piggybacks(processor, [%{tx_hash: tx_hash, output_index: 1}])
      {processor, _} = Core.new_piggybacks(processor, [%{tx_hash: tx_hash, output_index: 2}])

      {:ok, processor, [{:put, :in_flight_exit_info, _}]} =
        Core.finalize_in_flight_exits(processor, [%{in_flight_exit_id: ife_id, output_index: 1}])

      [_] = Core.get_active_in_flight_exits(processor)

      {:ok, processor, [{:put, :in_flight_exit_info, _}]} =
        Core.finalize_in_flight_exits(processor, [%{in_flight_exit_id: ife_id, output_index: 2}])

      assert [] == Core.get_active_in_flight_exits(processor)
    end

    @tag fixtures: [:processor_empty, :in_flight_exit_events, :contract_ife_statuses]
    test "finalizing multiple times does not do harm",
         %{
           processor_empty: processor,
           in_flight_exit_events: [ife | _],
           contract_ife_statuses: [{_, ife_id} = ife_status | _]
         } do
      {processor, _} = Core.new_in_flight_exits(processor, [ife], [ife_status])

      tx_hash = ife_tx_hash(ife)
      {processor, _} = Core.new_piggybacks(processor, [%{tx_hash: tx_hash, output_index: 1}])

      finalization = %{in_flight_exit_id: ife_id, output_index: 1}
      {:ok, processor, _} = Core.finalize_in_flight_exits(processor, [finalization])
      {:ok, ^processor, []} = Core.finalize_in_flight_exits(processor, [finalization])
    end

    @tag fixtures: [:processor_empty, :in_flight_exit_events, :contract_ife_statuses]
    test "finalizing perserve in flights exits that are not being finalized",
         %{
           processor_empty: processor,
           in_flight_exit_events: [ife1, ife2],
           contract_ife_statuses: [{_, ife_id} = ife_status1, ife_status2]
         } do
      {processor, _} = Core.new_in_flight_exits(processor, [ife1, ife2], [ife_status1, ife_status2])

      tx1_hash = ife_tx_hash(ife1)
      {processor, _} = Core.new_piggybacks(processor, [%{tx_hash: tx1_hash, output_index: 1}])
      finalization = %{in_flight_exit_id: ife_id, output_index: 1}
      {:ok, processor, _} = Core.finalize_in_flight_exits(processor, [finalization])

      tx2_hash = ife_tx_hash(ife2)
      [%{txhash: ^tx2_hash}] = Core.get_active_in_flight_exits(processor)
    end

    @tag fixtures: [:processor_empty, :in_flight_exit_events, :contract_ife_statuses]
    test "fails when unknown in-flight exit is being finalized", %{processor_empty: processor} do
      finalization = %{in_flight_exit_id: @non_zero_exit_id, output_index: 1}

      {:unknown_in_flight_exit, unknown_exits} = Core.finalize_in_flight_exits(processor, [finalization])
      assert unknown_exits == MapSet.new([<<@non_zero_exit_id::192>>])
    end

    @tag fixtures: [:processor_empty, :in_flight_exit_events, :contract_ife_statuses]
    test "fails when exiting an output that is not piggybacked",
         %{
           processor_empty: processor,
           in_flight_exit_events: [ife | _],
           contract_ife_statuses: [{_, ife_id} = ife_status | _]
         } do
      {processor, _} = Core.new_in_flight_exits(processor, [ife], [ife_status])

      tx_hash = ife_tx_hash(ife)
      {processor, _} = Core.new_piggybacks(processor, [%{tx_hash: tx_hash, output_index: 1}])

      finalization1 = %{in_flight_exit_id: ife_id, output_index: 1}
      finalization2 = %{in_flight_exit_id: ife_id, output_index: 2}

      expected_unknown_piggybacks = [%{in_flight_exit_id: <<ife_id::192>>, output_index: 2}]

      {:unknown_piggybacks, ^expected_unknown_piggybacks} =
        Core.finalize_in_flight_exits(processor, [finalization1, finalization2])
    end
  end

  defp ife_tx_hash(%{call_data: %{in_flight_tx: tx_bytes}}) do
    {:ok, tx} = tx_bytes |> Transaction.decode()
    Transaction.raw_txhash(tx)
  end

  defp mock_utxo_exists(%ExitProcessor.Request{utxos_to_check: positions} = request, state) do
    %{request | utxo_exists_result: positions |> Enum.map(&State.Core.utxo_exists?(&1, state))}
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

  defp invalid_exits_filtered(request, processor, opts) do
    exclude_events = Keyword.get(opts, :exclude, [])
    only_events = Keyword.get(opts, :only, [])

    {result, events} = Core.invalid_exits(request, processor)

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

  defp prepare_exit_finalizations(utxo_positions), do: Enum.map(utxo_positions, &%{utxo_pos: Utxo.Position.encode(&1)})

  #  Challenger

  defp create_block_with(blknum, txs) do
    %Block{
      number: blknum,
      transactions: Enum.map(txs, &Transaction.Signed.encode/1)
    }
  end

  defp assert_sig_belongs_to(sig, tx, expected_owner) do
    {:ok, signer_addr} =
      tx
      |> Transaction.raw_txhash()
      |> Crypto.recover_address(sig)

    assert expected_owner.addr == signer_addr
  end

  @tag fixtures: [:alice, :bob]
  test "creates a challenge for an exit; provides utxo position of non-zero amount", %{alice: alice, bob: bob} do
    # transactions spending one of utxos from above transaction
    tx_spending_1st_utxo =
      TestHelper.create_signed([{1, 0, 0, alice}, {1000, 0, 0, alice}], @eth, [{bob, 50}, {alice, 50}])

    tx_spending_2nd_utxo =
      TestHelper.create_signed([{1000, 0, 1, bob}, {1, 0, 0, alice}], @eth, [{alice, 50}, {bob, 50}])

    spending_block = create_block_with(2000, [tx_spending_1st_utxo, tx_spending_2nd_utxo])

    # Assert 1st spend challenge
    expected_txbytes = tx_spending_1st_utxo |> Transaction.raw_txbytes()

    assert %{
             exit_id: 424_242_424_242_424_242_424_242_424_242,
             input_index: 1,
             txbytes: ^expected_txbytes,
             sig: alice_signature
           } =
             Core.create_challenge(
               %ExitInfo{owner: alice.addr},
               spending_block,
               Utxo.position(1000, 0, 0),
               424_242_424_242_424_242_424_242_424_242
             )

    assert_sig_belongs_to(alice_signature, tx_spending_1st_utxo, alice)

    # Assert 2nd spend challenge
    expected_txbytes = tx_spending_2nd_utxo |> Transaction.raw_txbytes()

    assert %{
             exit_id: 333,
             input_index: 0,
             txbytes: ^expected_txbytes,
             sig: bob_signature
           } = Core.create_challenge(%ExitInfo{owner: bob.addr}, spending_block, Utxo.position(1000, 0, 1), 333)

    assert_sig_belongs_to(bob_signature, tx_spending_2nd_utxo, bob)
  end

  @tag fixtures: [:alice, :bob]
  test "create challenge based on ife", %{alice: alice, bob: bob} do
    tx = TestHelper.create_signed([{1000, 0, 0, alice}, {1000, 0, 1, alice}], @eth, [{bob, 50}, {alice, 50}])
    expected_txbytes = Transaction.raw_txbytes(tx)

    assert %{
             exit_id: 111,
             input_index: 1,
             txbytes: ^expected_txbytes,
             sig: alice_signature
           } = Core.create_challenge(%ExitInfo{owner: alice.addr}, tx, Utxo.position(1000, 0, 1), 111)
  end

  @tag fixtures: [:processor_filled, :alice]
  test "not spent or not existed utxo should be not challengeable", %{processor_filled: processor, alice: alice} do
    {block, exit_txbytes} = get_block_exit_txbytes(@utxo_pos1, alice)

    assert {:ok, 1000, %ExitInfo{}, ^exit_txbytes} = Core.get_challenge_data({:ok, 1000}, @utxo_pos1, block, processor)

    {block2, _exit_txbytes} = get_block_exit_txbytes(@utxo_pos2, alice)
    assert {:error, :utxo_not_spent} = Core.get_challenge_data({:ok, :not_found}, @utxo_pos2, block2, processor)
    {block3, _exit_txbytes} = get_block_exit_txbytes(@utxo_pos3, alice)
    assert {:error, :exit_not_found} = Core.get_challenge_data({:ok, 1000}, @utxo_pos3, block3, processor)
  end

  @tag fixtures: [:processor_filled, :alice, :transactions]
  test "challenges standard exits challengeable by IFE transactions",
       %{processor_filled: processor, alice: %{addr: alice_addr} = alice, transactions: [ife_tx | _]} do
    txbytes = Transaction.new([], [{alice_addr, @eth, 10}]) |> Transaction.raw_txbytes()

    event = %{
      owner: alice_addr,
      eth_height: 2,
      exit_id: 1,
      call_data: %{utxo_pos: Utxo.Position.encode(@utxo_pos3), output_tx: txbytes}
    }

    status = {alice_addr, @eth, 10, Utxo.Position.encode(@utxo_pos3)}
    {processor, _} = Core.new_exits(processor, [event], [status])
    {block, exit_txbytes} = get_block_exit_txbytes(@utxo_pos3, alice)

    assert {:ok, %Transaction.Signed{raw_tx: ^ife_tx}, %ExitInfo{owner: ^alice_addr}, ^exit_txbytes} =
             Core.get_challenge_data({:ok, :not_found}, @utxo_pos3, block, processor)
  end

  @tag fixtures: [:processor_empty, :alice]
  test "get exit txbytes from deposit", %{processor_empty: empty, alice: alice} do
    txbytes = Transaction.new([], [{alice.addr, @eth, 10}]) |> Transaction.raw_txbytes()

    exit_events = [
      %{
        owner: alice.addr,
        eth_height: 2,
        exit_id: 1,
        call_data: %{utxo_pos: Utxo.Position.encode(Utxo.position(1, 0, 0)), output_tx: txbytes}
      }
    ]

    contract_exit_statuses = [{alice.addr, @eth, 10, Utxo.Position.encode(Utxo.position(1, 0, 0))}]
    {processor, _} = Core.new_exits(empty, exit_events, contract_exit_statuses)

    assert {:ok, 1, %ExitInfo{}, ^txbytes} =
             Core.get_challenge_data({:ok, 1}, Utxo.position(1, 0, 0), :not_found, processor)
  end

  defp get_block_exit_txbytes(Utxo.position(blknum, txindex, oindex), owner) do
    recovered_tx_list =
      Enum.map(0..txindex, fn index ->
        TestHelper.create_recovered([{1, index + 1, 0, owner}], @eth, List.duplicate({owner, 8}, oindex + 1))
      end)

    exit_txbytes = Enum.at(recovered_tx_list, txindex) |> Transaction.raw_txbytes()

    {Block.hashed_txs_at(recovered_tx_list, blknum), exit_txbytes}
  end
end
