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
  Test of the logic of exit processor - not losing exits from persistence, emitting events, talking to API.State.Core
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.API.Fixtures

  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.API.DevCrypto
  alias OMG.API.State
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Watcher.Event
  alias OMG.API.TestHelper
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo
  alias OMG.Watcher.ExitProcessor.ExitInfo

  require Utxo

  @eth Crypto.zero_address()
  @not_eth <<1::size(160)>>

  @early_blknum 1_000
  @late_blknum 10_000

  @utxo_pos1 Utxo.position(1, 0, 0)
  @utxo_pos2 Utxo.position(@late_blknum - 1_000, 0, 1)

  @update_key1 {1, 0, 0}
  @update_key2 {@late_blknum - 1_000, 0, 1}

  @eth <<1::160>>

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

  # events is whatever `OMG.Eth` would feed into the `OMG.Watcher.ExitProcessor`, via `OMG.API.EthereumEventListener`
  deffixture exit_events(alice) do
    %{addr: alice} = alice

    [
      %{amount: 10, currency: @eth, owner: alice, utxo_pos: Utxo.Position.encode(@utxo_pos1), eth_height: 2},
      %{amount: 9, currency: @not_eth, owner: alice, utxo_pos: Utxo.Position.encode(@utxo_pos2), eth_height: 4}
    ]
  end

  deffixture in_flight_exit_events(transactions, alice) do
    %{priv: alice_priv} = alice

    [tx1_bytes, tx2_bytes] =
      transactions
      |> Enum.map(&Transaction.encode/1)

    [tx1_sigs, tx2_sigs] =
      transactions
      |> Enum.map(&DevCrypto.sign(&1, [alice_priv, alice_priv]))
      |> Enum.map(&Enum.join(&1.sigs))

    [
      %{call_data: %{in_flight_tx: tx1_bytes, in_flight_tx_sigs: tx1_sigs}, eth_height: 2},
      %{call_data: %{in_flight_tx: tx2_bytes, in_flight_tx_sigs: tx2_sigs}, eth_height: 4}
    ]
  end

  # extracts the mocked responses of the `Eth.RootChain.get_standard_exit` for the exit events
  # all exits active (owner non-zero). This is the auxiliary, second argument that's fed into `new_exits`
  deffixture contract_exit_statuses(exit_events) do
    exit_events
    |> Enum.map(fn %{amount: amount, currency: currency, owner: owner} -> {owner, currency, amount} end)
  end

  deffixture contract_ife_statuses(in_flight_exit_events) do
    List.duplicate({1, <<1::192>>}, length(in_flight_exit_events))
  end

  deffixture in_flight_exits(in_flight_exit_events, contract_ife_statuses) do
    Enum.zip(in_flight_exit_events, contract_ife_statuses)
    |> Enum.map(fn {event, status} -> build_in_flight_exit(event, status) end)
  end

  deffixture in_flight_exits_challenges_events(in_flight_exits, competing_transactions) do
    [{tx1_hash, _}, {tx2_hash, _}] = in_flight_exits
    [competing_tx1, competing_tx2, competing_tx3] = competing_transactions

    [
      %{
        tx_hash: tx1_hash,
        # in-flight transaction
        competitor_position: not_included_competitor_pos(),
        call_data: %{
          competing_tx: Transaction.encode(competing_tx1),
          competing_tx_input_index: 1,
          competing_tx_sig: <<0::520>>
        }
      },
      %{
        tx_hash: tx1_hash,
        # canonical transaction
        competitor_position: Utxo.position(1000, 0, 0) |> Utxo.Position.encode(),
        call_data: %{
          competing_tx: Transaction.encode(competing_tx2),
          competing_tx_input_index: 1,
          competing_tx_sig: <<0::520>>
        }
      },
      %{
        tx_hash: tx2_hash,
        # in-flight transaction
        competitor_position: not_included_competitor_pos(),
        call_data: %{
          competing_tx: Transaction.encode(competing_tx3),
          competing_tx_input_index: 2,
          competing_tx_sig: <<1::520>>
        }
      }
    ]
  end

  deffixture challenged_in_flight_exits(in_flight_exits, in_flight_exits_challenges_events) do
    ifes = Map.new(in_flight_exits)

    in_flight_exits_challenges_events
    |> Enum.map(fn %{tx_hash: ife_hash, competitor_position: position} ->
      {ife_hash, InFlightExitInfo.challenge(Map.get(ifes, ife_hash), position)}
    end)
    # removes intermediate updates of the same ife
    |> Map.new()
    |> Map.to_list()
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

  # TODO: will be removed, when persistence and behaviors are tested more thoroughly, without reaching into the guts
  defp build_in_flight_exit(
         %{call_data: %{in_flight_tx: bytes, in_flight_tx_sigs: sigs}},
         {timestamp, contract_ife_id}
       ) do
    {:ok, raw_tx} = Transaction.decode(bytes)

    # TODO rethink fixtures to avoid doing this
    chopped_sigs = for <<chunk::size(65)-unit(8) <- sigs>>, do: <<chunk::size(65)-unit(8)>>

    signed_tx = %Transaction.Signed{
      raw_tx: raw_tx,
      sigs: chopped_sigs
    }

    signed_tx = %{signed_tx | signed_tx_bytes: Transaction.Signed.encode(signed_tx)}

    {Transaction.hash(raw_tx), %InFlightExitInfo{tx: signed_tx, timestamp: timestamp, contract_id: contract_ife_id}}
  end

  @tag fixtures: [:processor_empty, :exit_events, :contract_exit_statuses]
  test "persist started exits and loads persisted on init", %{
    processor_empty: empty,
    exit_events: events,
    contract_exit_statuses: contract_statuses
  } do
    values =
      Enum.map(
        events,
        &(Map.put(&1, :is_active, true)
          |> Map.delete(:utxo_pos))
      )

    updates = Enum.zip([[:put, :put], [:exit_info, :exit_info], Enum.zip([@update_key1, @update_key2], values)])
    update1 = Enum.slice(updates, 0, 1)
    update2 = Enum.slice(updates, 1, 1)

    assert {state2, ^update1} = Core.new_exits(empty, Enum.slice(events, 0, 1), Enum.slice(contract_statuses, 0, 1))
    assert {final_state, ^updates} = Core.new_exits(empty, events, contract_statuses)

    assert {^final_state, ^update2} =
             Core.new_exits(state2, Enum.slice(events, 1, 1), Enum.slice(contract_statuses, 1, 1))

    {:ok, ^final_state} = Core.init(Enum.zip([@update_key1, @update_key2], values), [], [])
  end

  @tag fixtures: [:processor_empty, :alice, :exit_events]
  test "new_exits sanity checks", %{
    processor_empty: processor,
    alice: %{
      addr: alice
    },
    exit_events: [one_exit | _]
  } do
    {:error, :unexpected_events} =
      processor
      |> Core.new_exits([one_exit], [])

    {:error, :unexpected_events} =
      processor
      |> Core.new_exits([], [{alice, @eth, 10}])
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

    assert {^filled, []} = Core.finalize_exits(filled, {[], []})
  end

  @tag fixtures: [:processor_empty, :alice, :state_empty, :exit_events]
  test "handles invalid exit finalization - doesn't forget and causes a byzantine chain report", %{
    processor_empty: processor,
    alice: %{
      addr: alice
    },
    state_empty: state,
    exit_events: events
  } do
    {processor, _} =
      processor
      |> Core.new_exits(
        events,
        [{alice, @eth, 10}, {Crypto.zero_address(), @not_eth, 9}]
      )

    # exits invalidly finalize and continue/start emitting events and complain
    {:ok, {_, _, two_spend}, state_after_spend} =
      State.Core.exit_utxos(
        [
          %{utxo_pos: Utxo.Position.encode(@utxo_pos1)},
          %{utxo_pos: Utxo.Position.encode(@utxo_pos2)}
        ],
        state
      )

    # finalizing here - note that without `finalize_exits`, we would just get a single invalid exit event
    # with - we get 3, because we include the invalidly finalized on which will hurt forever
    assert {
             processor,
             [
               {:put, :exit_info, {@update_key1, %{is_active: true}}},
               {:put, :exit_info, {@update_key2, %{is_active: true}}}
             ]
           } = Core.finalize_exits(processor, two_spend)

    assert {{:error, :unchallenged_exit}, [_event1, _event2, _event3]} =
             %ExitProcessor.Request{eth_height_now: 12, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state_after_spend)
             |> Core.invalid_exits(processor)
  end

  @tag fixtures: [:processor_empty, :state_alice_deposit, :exit_events, :contract_exit_statuses]
  test "can work with State to determine valid exits and finalize them", %{
    processor_empty: processor,
    state_alice_deposit: state,
    exit_events: [one_exit | _],
    contract_exit_statuses: [one_status | _]
  } do
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
    {:ok, {_, _, spends}, _} = State.Core.exit_utxos([%{utxo_pos: Utxo.Position.encode(@utxo_pos1)}], state)
    assert {processor, [{:delete, :exit_info, @update_key1}]} = Core.finalize_exits(processor, spends)

    assert %ExitProcessor.Request{utxos_to_check: []} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)
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

    assert {processor, [{:delete, :exit_info, @update_key1}, {:delete, :exit_info, @update_key2}]} =
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
      |> Core.new_exits([one_exit], [{Crypto.zero_address(), @eth, 10}])

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

    assert %{utxos_to_check: [@utxo_pos1, Utxo.position(1, 2, 1) | _]} =
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
    assert [] == Core.get_in_flight_exits(processor)

    {processor, _} = Core.new_in_flight_exits(processor, events, statuses)
    ifes_response = Core.get_in_flight_exits(processor)

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
               txbytes: Transaction.encode(tx1),
               txhash: Transaction.hash(tx1),
               eth_height: 2,
               piggybacked_inputs: [],
               piggybacked_outputs: []
             },
             %{
               txbytes: Transaction.encode(tx2),
               txhash: Transaction.hash(tx2),
               eth_height: 4,
               piggybacked_inputs: [],
               piggybacked_outputs: []
             }
           ] == Core.get_in_flight_exits(processor) |> Enum.sort_by(& &1.eth_height)
  end

  @tag fixtures: [:processor_empty, :in_flight_exit_events, :contract_ife_statuses, :transactions]
  test "reports piggybacked inputs/outputs when getting ifes", %{
    processor_empty: processor,
    in_flight_exit_events: [event | _],
    contract_ife_statuses: [status | _],
    transactions: [tx | _]
  } do
    txhash = Transaction.hash(tx)
    {processor, _} = Core.new_in_flight_exits(processor, [event], [status])
    assert [%{piggybacked_inputs: [], piggybacked_outputs: []}] = Core.get_in_flight_exits(processor)

    {processor, _} = Core.new_piggybacks(processor, [%{tx_hash: txhash, output_index: 0}])

    assert [%{piggybacked_inputs: [0], piggybacked_outputs: []}] = Core.get_in_flight_exits(processor)

    {processor, _} =
      Core.new_piggybacks(processor, [%{tx_hash: txhash, output_index: 4}, %{tx_hash: txhash, output_index: 5}])

    assert [%{piggybacked_inputs: [0], piggybacked_outputs: [0, 1]}] = Core.get_in_flight_exits(processor)
  end

  test "persists in flight exits and loads persisted on init",
       %{} do
    # TODO such end-to-end persistence tests are too brittle now, must do OMG-329
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

  test "persists new piggybacks",
       %{} do
    # TODO such end-to-end persistence tests are too brittle now, must do OMG-329
  end

  @tag fixtures: [:processor_filled, :in_flight_exits]
  test "piggybacking sanity checks", %{processor_filled: state, in_flight_exits: [{ife_id, ife} | _]} do
    {^state, []} = Core.new_piggybacks(state, [])
    catch_error(Core.new_piggybacks(state, [%{tx_hash: 0, output_index: 0}]))
    catch_error(Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 8}]))

    # cannot piggyback twice the same output
    {updated_state, [_]} = Core.new_piggybacks(state, [%{tx_hash: ife_id, output_index: 0}])
    catch_error(Core.new_piggybacks(updated_state, [%{tx_hash: ife_id, output_index: 0}]))

    # piggybacked outputs are considered as piggybacked
    {:ok, piggybacked_ife} = InFlightExitInfo.piggyback(ife, 0)
    assert InFlightExitInfo.is_piggybacked?(piggybacked_ife, 0)

    # other outputs are considered as not piggybacked
    assert 1..7
           |> Enum.reduce(true, fn
             index, true -> !InFlightExitInfo.is_piggybacked?(piggybacked_ife, index)
             _, false -> false
           end)
  end

  test "persists new competitors and loads persisted on init", %{} do
    # TODO such end-to-end persistence tests are too brittle now, must do OMG-329
  end

  @tag fixtures: [:processor_filled, :in_flight_exits_challenges_events]
  test "can challenge an in flight exit and challenged ife is not forgotten", %{
    processor_filled: processor,
    in_flight_exits_challenges_events: [challenge | _]
  } do
    assert Core.get_in_flight_exits(processor) |> Enum.count() == 2
    {processor2, _} = Core.new_ife_challenges(processor, [challenge])
    # TODO: test persistence separately
    assert Core.get_in_flight_exits(processor2) |> Enum.count() == 2
    # sanity
    assert processor2 != processor
  end

  @tag fixtures: [:processor_filled, :in_flight_exits]
  test "forgets challenged piggybacks",
       %{processor_filled: processor, in_flight_exits: ifes} do
    events = ifes |> Enum.map(fn {tx_hash, _} -> %{tx_hash: tx_hash, output_index: 0} end)

    {processor, _} = Core.new_piggybacks(processor, events)
    # sanity: there are some piggybacks after piggybacking, to be removed later
    assert [%{piggybacked_inputs: [_]}, %{piggybacked_inputs: [_]}] = Core.get_in_flight_exits(processor)
    %{tx_hash: challenged_tx_hash} = to_challenge = hd(events)
    {processor, _} = Core.challenge_piggybacks(processor, [to_challenge])

    # TODO test persistence separately
    assert [%{txhash: ^challenged_tx_hash, piggybacked_inputs: []}, %{piggybacked_inputs: [0]}] =
             Core.get_in_flight_exits(processor)
             |> Enum.sort_by(&length(&1.piggybacked_inputs))
  end

  @tag fixtures: [:processor_filled, :in_flight_exits]
  test "can open and challenge two piggybacks at one call",
       %{processor_filled: processor, in_flight_exits: ifes} do
    events = ifes |> Enum.map(fn {tx_hash, _} -> %{tx_hash: tx_hash, output_index: 0} end)

    {processor, _} = Core.new_piggybacks(processor, events)
    # sanity: there are some piggybacks after piggybacking, to be removed later
    assert [%{piggybacked_inputs: [_]}, %{piggybacked_inputs: [_]}] = Core.get_in_flight_exits(processor)
    {processor, _} = Core.challenge_piggybacks(processor, events)

    # TODO test persistence ersistence separately
    assert [%{piggybacked_inputs: []}, %{piggybacked_inputs: []}] = Core.get_in_flight_exits(processor)
  end

  @tag fixtures: [:processor_filled, :in_flight_exits]
  test "challenge piggybacks sanity checks", %{processor_filled: state, in_flight_exits: [{tx_hash, ife}, _]} do
    # cannot challenge piggyback of unknown ife
    assert {state, []} == Core.challenge_piggybacks(state, [%{tx_hash: 0, output_index: 0}])

    # cannot challenge not piggybacked output
    assert {state, []} == Core.challenge_piggybacks(state, [%{tx_hash: tx_hash, output_index: 0}])

    # other sanity checks
    assert {state, []} == Core.challenge_piggybacks(state, [%{tx_hash: tx_hash, output_index: 8}])

    # challenged piggyback is considered as not piggybacked
    {:ok, piggybacked_ife} = InFlightExitInfo.piggyback(ife, 0)
    {:ok, challenged} = InFlightExitInfo.challenge_piggyback(piggybacked_ife, 0)

    assert 0..7
           |> Enum.reduce(true, fn
             index, true -> !InFlightExitInfo.is_piggybacked?(challenged, index)
             _, false -> false
           end)
  end

  @tag fixtures: [:processor_filled, :in_flight_exits]
  test "start standard exit challenge using ife tx as spend", %{
    processor_filled: state,
    in_flight_exits: [{tx_hash, ife}, _]
  } do
  end

  test "start standard exit challenge using ife tx as spend which was piggybacked and finalized" do
  end

  describe "available piggybacks" do
    @tag fixtures: [:processor_filled, :transactions, :alice]
    test "detects multiple available piggybacks, with all the fields",
         %{
           processor_filled: processor,
           transactions: [tx1, tx2],
           alice: alice
         } do
      [%{owner: tx1_owner1}, %{owner: tx1_owner2}, _, _] = Transaction.get_outputs(tx1)
      [%{owner: tx2_owner1}, %{owner: tx2_owner2}, _, _] = Transaction.get_outputs(tx2)

      txbytes_1 = Transaction.encode(tx1)
      txbytes_2 = Transaction.encode(tx2)

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
      txbytes = Transaction.encode(tx)
      signature = DevCrypto.sign(tx, [alice.priv]) |> Map.get(:sigs) |> Enum.join()

      ife_event = %{call_data: %{in_flight_tx: txbytes, in_flight_tx_sigs: signature}, eth_height: 2}
      ife_status = {1, <<1::192>>}

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
      {:ok, recovered_tx1} = DevCrypto.sign(tx1, [alice.priv, alice.priv]) |> Transaction.Recovered.recover_from()

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([recovered_tx1], 3000)]
      }

      txbytes_2 = Transaction.encode(tx2)

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

      txbytes = Transaction.encode(tx)
      signature = DevCrypto.sign(tx, [alice.priv, bob.priv]) |> Map.get(:sigs) |> Enum.join()

      ife_event = %{call_data: %{in_flight_tx: txbytes, in_flight_tx_sigs: signature}, eth_height: 2}
      ife_status = {1, <<1::192>>}

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

  describe "finds competitors and allows canonicity challenges" do
    @tag fixtures: [:processor_filled, :in_flight_exits]
    test "none if input never spent elsewhere",
         %{processor_filled: processor} do
      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> invalid_exits_filtered(processor, exclude: [Event.PiggybackAvailable])
    end

    @tag fixtures: [:processor_filled, :transactions, :competing_transactions, :alice]
    test "none if different input spent in some tx from appendix",
         %{processor_filled: processor, transactions: [tx1 | _], competing_transactions: [_, _, comp3], alice: alice} do
      txbytes = Transaction.encode(tx1)

      other_txbytes = Transaction.encode(comp3)
      other_signature = DevCrypto.sign(comp3, [alice.priv, alice.priv]) |> Map.get(:sigs) |> Enum.join()

      other_ife_event = %{call_data: %{in_flight_tx: other_txbytes, in_flight_tx_sigs: other_signature}, eth_height: 2}
      other_ife_status = {1, <<1::192>>}

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
      txbytes = Transaction.encode(tx1)

      {:ok, other_recovered} = DevCrypto.sign(comp3, [alice.priv, alice.priv]) |> Transaction.Recovered.recover_from()

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
      txbytes = Transaction.encode(tx1)

      {:ok, other_recovered} = DevCrypto.sign(tx1, [alice.priv, alice.priv]) |> Transaction.Recovered.recover_from()

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
      txbytes = Transaction.encode(tx1)

      other_txbytes = Transaction.encode(tx1)
      %{sigs: [other_signature, _]} = DevCrypto.sign(tx1, [alice.priv, alice.priv])

      other_ife_event = %{call_data: %{in_flight_tx: other_txbytes, in_flight_tx_sigs: other_signature}, eth_height: 2}
      other_ife_status = {1, <<1::192>>}

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
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _], competing_transactions: [comp1 | _]} do
      txbytes = Transaction.encode(tx1)

      other_txbytes = Transaction.encode(comp1)
      %{sigs: [other_signature, _]} = DevCrypto.sign(comp1, [alice.priv, <<>>])

      other_ife_event = %{call_data: %{in_flight_tx: other_txbytes, in_flight_tx_sigs: other_signature}, eth_height: 2}
      other_ife_status = {1, <<1::192>>}

      {processor, _} = Core.new_in_flight_exits(processor, [other_ife_event], [other_ife_status])

      assert {:ok, events} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> invalid_exits_filtered(processor, only: [Event.NonCanonicalIFE])

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

      txbytes = Transaction.encode(tx1)
      other_txbytes = Transaction.encode(competing_tx)

      challenge_event = %{
        tx_hash: Transaction.hash(tx2),
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
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _], competing_transactions: [comp1 | _]} do
      txbytes = Transaction.encode(tx1)

      other_txbytes = Transaction.encode(comp1)

      {:ok, %{signed_tx: %{sigs: [other_signature, _]}} = other_recovered} =
        DevCrypto.sign(comp1, [alice.priv, alice.priv]) |> Transaction.Recovered.recover_from()

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

      txbytes = Transaction.encode(tx1)

      check = fn {comp, {competing_input_index, in_flight_input_index}} ->
        # unfortunately, transaction validity requires us to duplicate a signature for every non-zero input
        required_priv_key_list =
          comp
          |> Transaction.get_inputs()
          |> Enum.filter(&Utxo.Position.non_zero?/1)
          |> Enum.count()
          |> (&List.duplicate(alice.priv, &1)).()

        {:ok, other_recovered} = comp |> DevCrypto.sign(required_priv_key_list) |> Transaction.Recovered.recover_from()

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
           competing_transactions: [comp1 | _]
         } do
      txbytes = Transaction.encode(tx1)

      {:ok, %{signed_tx: %{sigs: [_, other_signature]}} = other_recovered} =
        DevCrypto.sign(comp1, [bob.priv, alice.priv]) |> Transaction.Recovered.recover_from()

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
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _], competing_transactions: [comp1 | _]} do
      # NOTE that the recent competitor spends an __older__ input. Also note the reversing of block results done below
      #      Regardless of these, the best competitor (from blknum 2000) must always be returned
      # NOTE also that non-included competitors always are considered last, and hence worst and never are returned

      # first the included competitors
      comp_recent = Transaction.new([{1, 0, 0}], [])
      comp_oldest = Transaction.new([{1, 2, 1}], [])

      {:ok, recovered_recent} = DevCrypto.sign(comp_recent, [alice.priv]) |> Transaction.Recovered.recover_from()
      {:ok, recovered_oldest} = DevCrypto.sign(comp_oldest, [alice.priv]) |> Transaction.Recovered.recover_from()

      # ife-related competitor
      other_ife_event = %{
        call_data: %{in_flight_tx: Transaction.encode(comp1), in_flight_tx_sigs: <<4::520>>},
        eth_height: 2
      }

      other_ife_status = {1, <<1::192>>}
      {processor, _} = Core.new_in_flight_exits(processor, [other_ife_event], [other_ife_status])

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([recovered_oldest], 2000), Block.hashed_txs_at([recovered_recent], 3000)]
      }

      txbytes = Transaction.encode(tx1)

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
      txbytes = Transaction.encode(tx)
      %{sigs: [signature, _]} = DevCrypto.sign(tx, [alice.priv, <<>>])

      ife_event = %{call_data: %{in_flight_tx: txbytes, in_flight_tx_sigs: signature}, eth_height: 2}
      # inactive
      ife_status = {0, <<1::192>>}

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

    @tag fixtures: [:alice, :processor_filled, :state_alice_deposit]
    test "by working with State - only asking for spends concerning ifes",
         %{
           alice: alice,
           processor_filled: processor,
           state_alice_deposit: state
         } do
      other_recovered = OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 8}])

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

      assert %{blknums_to_get: [2000, 1000]} =
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
      txbytes = Transaction.encode(tx)

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
      txbytes = Transaction.encode(tx1)

      other_blknum = 3000

      block =
        txs
        |> Enum.map(fn tx1 ->
          {:ok, tx1_recovered} = DevCrypto.sign(tx1, [alice.priv, alice.priv]) |> Transaction.Recovered.recover_from()
          tx1_recovered
        end)
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
      txbytes = Transaction.encode(tx)

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

  #  Challenger

  defp create_block_with(blknum, txs) do
    %Block{
      number: blknum,
      transactions: Enum.map(txs, & &1.signed_tx_bytes)
    }
  end

  defp assert_sig_belongs_to(sig, %Transaction.Signed{raw_tx: raw_tx}, expected_owner) do
    {:ok, signer_addr} =
      raw_tx
      |> Transaction.hash()
      |> Crypto.recover_address(sig)

    assert expected_owner.addr == signer_addr
  end

  @tag fixtures: [:alice, :bob]
  test "creates a challenge for an exit; provides utxo position of non-zero amount", %{alice: alice, bob: bob} do
    # transactions spending one of utxos from above transaction
    tx_spending_1st_utxo =
      TestHelper.create_signed([{0, 0, 0, alice}, {1000, 0, 0, alice}], @eth, [{bob, 50}, {alice, 50}])

    tx_spending_2nd_utxo =
      TestHelper.create_signed([{1000, 0, 1, bob}, {0, 0, 0, alice}], @eth, [{alice, 50}, {bob, 50}])

    spending_block = create_block_with(2000, [tx_spending_1st_utxo, tx_spending_2nd_utxo])

    # Assert 1st spend challenge
    expected_utxo_pos = Utxo.position(1000, 0, 0) |> Utxo.Position.encode()
    expected_txbytes = tx_spending_1st_utxo.raw_tx |> Transaction.encode()

    assert %{
             utxo_pos: ^expected_utxo_pos,
             input_index: 1,
             txbytes: ^expected_txbytes,
             sig: alice_signature
           } = Core.create_challenge(%ExitInfo{owner: alice.addr}, spending_block, Utxo.position(1000, 0, 0))

    assert_sig_belongs_to(alice_signature, tx_spending_1st_utxo, alice)

    # Assert 2nd spend challenge
    expected_utxo_pos = Utxo.position(1000, 0, 1) |> Utxo.Position.encode()
    expected_txbytes = tx_spending_2nd_utxo.raw_tx |> Transaction.encode()

    assert %{
             utxo_pos: ^expected_utxo_pos,
             input_index: 0,
             txbytes: ^expected_txbytes,
             sig: bob_signature
           } = Core.create_challenge(%ExitInfo{owner: bob.addr}, spending_block, Utxo.position(1000, 0, 1))

    assert_sig_belongs_to(bob_signature, tx_spending_2nd_utxo, bob)
  end

  test "not spent or not existed utxo should be not challengeable" do
    exit_info = %{owner: "alice"}
    assert {:ok, 1000, %ExitInfo{owner: "alice"}} = Core.ensure_challengeable({:ok, 1000}, {:ok, {{}, exit_info}})

    assert {:error, :utxo_not_spent} = Core.ensure_challengeable({:ok, :not_found}, {:ok, {{}, exit_info}})
    assert {:error, :exit_not_found} = Core.ensure_challengeable({:ok, 1000}, {:ok, :not_found})

    assert {:error, :db_other_error1} = Core.ensure_challengeable({:error, :db_other_error1}, {:ok, {{}, exit_info}})
    assert {:error, :db_other_error2} = Core.ensure_challengeable({:ok, 1000}, {:error, :db_other_error2})
  end
end
