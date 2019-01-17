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

  alias OMG.API.Crypto
  alias OMG.API.State
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor.CompetitorInfo
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo

  require Utxo

  @eth Crypto.zero_address()
  @not_eth <<1::size(160)>>

  @early_blknum 1_000
  @late_blknum 10_000

  @utxo_pos1 Utxo.position(1, 0, 0)
  @utxo_pos2 Utxo.position(@late_blknum - 1_000, 0, 1)

  @update_key1 {1, 0, 0}
  @update_key2 {@late_blknum - 1_000, 0, 1}

  defp not_included_competitor_pos do
    <<long::256>> =
      List.duplicate(<<255::8>>, 32)
      |> Enum.reduce(fn val, acc -> val <> acc end)

    long
  end

  deffixture transactions() do
    [
      %Transaction{
        inputs: [%{blknum: 1, txindex: 1, oindex: 0}, %{blknum: 1, txindex: 2, oindex: 1}],
        outputs: [
          %{owner: "alicealicealicealice", currency: @eth, amount: 1},
          %{owner: "carolcarolcarolcarol", currency: @eth, amount: 2}
        ]
      },
      %Transaction{
        inputs: [%{blknum: 2, txindex: 1, oindex: 0}, %{blknum: 2, txindex: 2, oindex: 1}],
        outputs: [
          %{owner: "alicealicealicealice", currency: @eth, amount: 1},
          %{owner: "carolcarolcarolcarol", currency: @eth, amount: 2}
        ]
      }
    ]
  end

  deffixture competing_transactions() do
    [
      %Transaction{
        inputs: [%{blknum: 10, txindex: 2, oindex: 1}, %{blknum: 1, txindex: 1, oindex: 0}],
        outputs: [
          %{owner: "malorymalorymaloryma", currency: @eth, amount: 2},
          %{owner: "carolcarolcarolcarol", currency: @eth, amount: 1}
        ]
      },
      %Transaction{
        inputs: [%{blknum: 1, txindex: 1, oindex: 0}, %{blknum: 10, txindex: 2, oindex: 1}],
        outputs: [
          %{owner: "alicealicealicealice", currency: @eth, amount: 2},
          %{owner: "malorymalorymaloryma", currency: @eth, amount: 1}
        ]
      },
      %Transaction{
        inputs: [%{blknum: 20, txindex: 1, oindex: 0}, %{blknum: 2, txindex: 2, oindex: 1}],
        outputs: [
          %{owner: "malorymalorymaloryma", currency: @eth, amount: 2},
          %{owner: "carolcarolcarolcarol", currency: @eth, amount: 1}
        ]
      }
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

    [tx1_signs, tx2_sings] =
      transactions
      |> Enum.map(&Transaction.sign(&1, [alice_priv, alice_priv]))
      |> Enum.map(& &1.sigs)

    [
      %{tx_bytes: tx1_bytes, signatures: tx1_signs},
      %{tx_bytes: tx2_bytes, signatures: tx2_sings}
    ]
  end

  # extracts the mocked responses of the `Eth.RootChain.get_exit` for the exit events
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
        competitor_position: 100,
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

  defp build_in_flight_exit(%{tx_bytes: bytes, signatures: signs}, {timestamp, contract_ife_id}) do
    {:ok, raw_tx} = Transaction.decode(bytes)

    signed_tx = %Transaction.Signed{
      raw_tx: raw_tx,
      sigs: signs
    }

    {Transaction.hash(raw_tx), %InFlightExitInfo{tx: signed_tx, timestamp: timestamp, contract_id: contract_ife_id}}
  end

  defp build_competitor(%{
         call_data: %{
           competing_tx: tx_bytes,
           competing_tx_input_index: input_index,
           competing_tx_sig: signature
         }
       }) do
    CompetitorInfo.new(tx_bytes, input_index, signature)
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
             processor
             |> Core.get_exiting_utxo_positions()
             |> Enum.map(&State.Core.utxo_exists?(&1, state_after_spend))
             |> Core.invalid_exits(processor, 12, @late_blknum)
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
             processor
             |> Core.get_exiting_utxo_positions()
             |> Enum.map(&State.Core.utxo_exists?(&1, state))
             |> Core.invalid_exits(processor, 5, @late_blknum)

    # go into the future - old exits work the same
    assert {:ok, []} =
             processor
             |> Core.get_exiting_utxo_positions()
             |> Enum.map(&State.Core.utxo_exists?(&1, state))
             |> Core.invalid_exits(processor, 105, @late_blknum)

    # exit validly finalizes and continues to not emit any events
    {:ok, {_, _, spends}, _} = State.Core.exit_utxos([%{utxo_pos: Utxo.Position.encode(@utxo_pos1)}], state)
    assert {processor, [{:delete, :exit_info, @update_key1}]} = Core.finalize_exits(processor, spends)
    assert [] = Core.get_exiting_utxo_positions(processor)
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
             processor
             |> Core.get_exiting_utxo_positions()
             |> Enum.map(&State.Core.utxo_exists?(&1, state))
             |> Core.invalid_exits(processor, 5, @late_blknum)
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
    assert [_, _] = Core.get_exiting_utxo_positions(processor)

    assert {processor, [{:delete, :exit_info, @update_key1}, {:delete, :exit_info, @update_key2}]} =
             processor
             |> Core.challenge_exits([
               %{utxo_pos: Utxo.Position.encode(@utxo_pos1)},
               %{utxo_pos: Utxo.Position.encode(@utxo_pos2)}
             ])

    assert [] = Core.get_exiting_utxo_positions(processor)
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
             processor
             |> Core.get_exiting_utxo_positions()
             |> Enum.map(&State.Core.utxo_exists?(&1, state))
             |> Core.invalid_exits(processor, 13, @late_blknum)
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
             processor
             |> Core.get_exiting_utxo_positions()
             |> Enum.map(&State.Core.utxo_exists?(&1, state))
             |> Core.invalid_exits(processor, 13, @late_blknum)
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
             processor
             |> Core.get_exiting_utxo_positions()
             |> Enum.map(&State.Core.utxo_exists?(&1, state))
             |> Core.invalid_exits(processor, 13, @early_blknum)
  end

  @tag fixtures: [:processor_empty]
  test "empty processor returns no exiting utxo positions", %{processor_empty: empty} do
    assert [] = Core.get_exiting_utxo_positions(empty)
  end

  @tag fixtures: [:processor_empty]
  test "empty processor returns no in flight exits", %{processor_empty: empty} do
    assert %{} == Core.get_in_flight_exits(empty)
  end

  @tag fixtures: [:processor_empty, :in_flight_exit_events, :contract_ife_statuses, :in_flight_exits]
  test "properly processes new in flight exits", %{
    processor_empty: empty,
    in_flight_exit_events: events,
    contract_ife_statuses: statuses,
    in_flight_exits: ifes
  } do
    {updated_state, _} = Core.new_in_flight_exits(empty, events, statuses)

    assert Map.new(ifes) == Core.get_in_flight_exits(updated_state)
  end

  @tag fixtures: [:processor_empty, :in_flight_exit_events, :contract_ife_statuses, :in_flight_exits]
  test "persists in flight exits and loads persisted on init", %{
    processor_empty: empty,
    in_flight_exit_events: events,
    contract_ife_statuses: statuses,
    in_flight_exits: ifes
  } do
    updates = Enum.map(ifes, &InFlightExitInfo.make_db_update/1)
    update1 = Enum.slice(updates, 0, 1)
    update2 = Enum.slice(updates, 1, 1)

    assert {updated_state, ^update1} =
             Core.new_in_flight_exits(empty, Enum.slice(events, 0, 1), Enum.slice(statuses, 0, 1))

    assert {final_state, ^updates} = Core.new_in_flight_exits(empty, events, statuses)

    assert {^final_state, ^update2} =
             Core.new_in_flight_exits(updated_state, Enum.slice(events, 1, 1), Enum.slice(statuses, 1, 1))

    {:ok, ^final_state} = Core.init([], ifes, [])
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

  @tag fixtures: [:processor_filled, :in_flight_exits]
  test "persists new piggybacks", %{processor_filled: state, in_flight_exits: ifes} do
    {piggybacked, events} =
      ifes
      |> Enum.reduce(
        {[], []},
        fn {id, ife}, {piggybacked, events} ->
          {:ok, updated_ife} = InFlightExitInfo.piggyback(ife, 0)
          {[{id, updated_ife} | piggybacked], [%{tx_hash: id, output_index: 0} | events]}
        end
      )

    expected_db_updates = Enum.map(piggybacked, &InFlightExitInfo.make_db_update/1)
    {state, db_updates} = Core.new_piggybacks(state, events)

    # updates does not necessarily come in the same order as events
    assert length(expected_db_updates) == length(db_updates)
    assert db_updates -- expected_db_updates == []

    assert Map.new(piggybacked) == Core.get_in_flight_exits(state)
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

  @tag fixtures: [:processor_filled, :in_flight_exits]
  test "can piggyback two outputs at one call", %{processor_filled: state, in_flight_exits: ifes} do
    events =
      ifes
      |> Enum.reduce([], fn {tx_hash, _}, acc ->
        [%{tx_hash: tx_hash, output_index: 0}, %{tx_hash: tx_hash, output_index: 1} | acc]
      end)

    piggybacked =
      ifes
      |> Enum.map(fn {tx_hash, ife} ->
        {:ok, tmp} = InFlightExitInfo.piggyback(ife, 0)
        {:ok, updated} = InFlightExitInfo.piggyback(tmp, 1)
        {tx_hash, updated}
      end)

    {state, db_updates} = Core.new_piggybacks(state, events)

    assert Map.new(piggybacked) == Core.get_in_flight_exits(state)
    assert length(db_updates) == length(piggybacked)
  end

  #  @tag fixtures: [:processor_empty, :alice, :in_flight_exit_events]
  #  test "active piggybacks from inputs are monitored", %{
  #    processor_empty: empty,
  #    in_flight_exit_events: ife_events
  #  } do
  #    Core.new_in_flight_exits(empty, [timestamp: 1001], ife_events)
  #  end

  @tag fixtures: [:in_flight_exits, :in_flight_exits_challenges_events, :challenged_in_flight_exits]
  test "persists new competitors and loads persisted on init", %{
    in_flight_exits: ifes,
    challenged_in_flight_exits: challenged_ifes,
    in_flight_exits_challenges_events: challenges_events
  } do
    {:ok, state} = Core.init([], ifes, [])

    competitors =
      challenges_events
      |> Enum.map(&build_competitor/1)

    updates = Enum.map(competitors, &CompetitorInfo.make_db_update/1)

    {updated_state, db_updates} = Core.new_ife_challenges(state, Enum.slice(challenges_events, 0, 1))

    assert Enum.member?(db_updates, Enum.at(updates, 0))

    {final_state, db_updates} = Core.new_ife_challenges(state, challenges_events)

    # updates consists of competitors updates as well as ifes updates
    assert Enum.reduce(
             updates,
             true,
             fn
               update, true -> Enum.member?(db_updates, update)
               _, false -> false
             end
           )

    assert {^final_state, db_updates} = Core.new_ife_challenges(updated_state, Enum.slice(challenges_events, 1, 2))

    assert Enum.reduce(
             Enum.slice(updates, 1, 2),
             true,
             fn
               update, true -> Enum.member?(db_updates, update)
               _, false -> false
             end
           )

    {:ok, ^final_state} = Core.init([], challenged_ifes, competitors)
  end

  @tag fixtures: [:processor_empty, :in_flight_exits, :in_flight_exits_challenges_events]
  test "can challenge an in flight exit and challenged ife is not forgotten", %{
    in_flight_exits: [{tx_hash, _} = ife | _],
    in_flight_exits_challenges_events: [challenge | _]
  } do
    {:ok, state} = Core.init([], [ife], [])

    {state, updates} = Core.new_ife_challenges(state, [challenge])

    assert Enum.any?(
             updates,
             fn
               {:put, :in_flight_exit_info, {^tx_hash, ife}} -> !InFlightExitInfo.is_canonical?(ife)
               _ -> false
             end
           )

    assert Core.get_in_flight_exits(state, [tx_hash])
           |> Map.get(tx_hash)
           |> (&(!InFlightExitInfo.is_canonical?(&1))).()
  end

  test "in flight exits are found by competitor finder" do
  end

  test "competitors are found by competitor finder" do
  end

  @tag fixtures: [:processor_filled, :in_flight_exits]
  test "forgets challenged piggybacks", %{processor_filled: state, in_flight_exits: ifes} do
    events =
      ifes
      |> Enum.map(fn {tx_hash, _} -> %{tx_hash: tx_hash, output_index: 0} end)

    piggyback_events = challenge_events = events

    {state_with_piggybacks, _} = Core.new_piggybacks(state, piggyback_events)
    piggybacked_ifes = Core.get_in_flight_exits(state_with_piggybacks)

    challenged_ifes =
      piggybacked_ifes
      |> Enum.map(fn {tx_hash, ife} ->
        {:ok, challenged} = InFlightExitInfo.challenge_piggyback(ife, 0)
        {tx_hash, challenged}
      end)

    expected_db_updates = challenged_ifes |> Enum.map(&InFlightExitInfo.make_db_update/1)

    {final_state, db_updates} = Core.challenge_piggybacks(state_with_piggybacks, challenge_events)
    assert Core.get_in_flight_exits(final_state) == Map.new(ifes)

    # order of updates is not deterministic
    assert length(db_updates) == length(expected_db_updates)
    assert db_updates -- expected_db_updates == []
  end

  @tag fixtures: [:in_flight_exits]
  test "can challenge two piggybacks at one call", %{in_flight_exits: [ife | _]} do
    {tx_hash, tmp} = ife
    {:ok, tmp} = InFlightExitInfo.piggyback(tmp, 0)
    {:ok, piggybacked_ife} = InFlightExitInfo.piggyback(tmp, 1)

    {:ok, state} = Core.init([], [{tx_hash, piggybacked_ife}], [])

    events = [%{tx_hash: tx_hash, output_index: 0}, %{tx_hash: tx_hash, output_index: 1}]

    expected_db_updates = InFlightExitInfo.make_db_update(ife)

    assert {final_state, [^expected_db_updates]} = Core.challenge_piggybacks(state, events)
    assert Core.get_in_flight_exits(final_state) == Map.new([ife])
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

  describe "finds competitors and allows challenges" do
    @tag fixtures: [:processor_filled, :in_flight_exits]
    test "none if input never spent elsewhere",
         %{processor_filled: processor} do
      assert [] = Core.get_ifes_with_competitors(processor)
    end

    test "none if different input spent in some tx from appendix",
         %{} do
    end

    test "none if different input spent in some tx from block",
         %{} do
    end

    test "none if input spent in _same_ tx in block",
         %{} do
    end

    test "none if input spent in _same_ tx in tx appendix",
         %{} do
    end

    @tag fixtures: [:alice, :processor_filled, :transactions, :competing_transactions]
    test "each other, if input spent in different ife",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _], competing_transactions: [comp1 | _]} do
      txbytes = Transaction.encode(tx1)

      other_txbytes = comp1 |> Transaction.encode()
      %{sigs: [other_signature, _]} = Transaction.sign(comp1, [alice.priv, <<>>])

      other_ife_event = %{tx_bytes: other_txbytes, signatures: [other_signature]}
      other_ife_status = {1, <<1::192>>}

      {processor, _} = Core.new_in_flight_exits(processor, [other_ife_event], [other_ife_status])

      assert [^other_txbytes, ^txbytes] = Core.get_ifes_with_competitors(processor)

      # TODO: we return a competitor probably we prefer the best competitor here
      assert %{
               inflight_txbytes: ^txbytes,
               inflight_input_index: 0,
               competing_txbytes: ^other_txbytes,
               competing_input_index: 1,
               competing_sig: ^other_signature,
               competing_txid: nil,
               competing_proof: nil
             } = Core.get_competitor_for_ife(processor, [alice.addr], txbytes)
    end

    test "a competitor that's submitted as challenged to other IFE",
         %{} do
    end

    test "a single competitor included in a block, with proof",
         %{} do
    end

    test "a best competitor, included earliest in a block",
         %{} do
    end

    test "works with State to find competitors",
         %{} do
    end

    test "none if input not yet created during sync",
         %{} do
    end
  end
end
