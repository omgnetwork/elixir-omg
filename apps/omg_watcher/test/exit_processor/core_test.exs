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
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo
  alias OMG.Watcher.ExitProcessor.CompetitorInfo

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
    <<long::256>> = List.duplicate(<<255::8>>, 32) |> Enum.reduce(fn val, acc -> val <> acc end)
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
        inputs: [%{blknum: 1, txindex: 1, oindex: 0}, %{blknum: 10, txindex: 2, oindex: 1}],
        outputs: [
          %{owner: "malorymalorymaloryma", currency: @eth, amount: 2},
          %{owner: "carolcarolcarolcarol", currency: @eth, amount: 1}
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

    [tx1_bytes, tx2_bytes] = transactions |> Enum.map(&Transaction.encode/1)

    [tx1_signs, tx2_sings] =
      transactions
      |> Enum.map(&Transaction.sign(&1, [alice_priv, alice_priv]))
      |> Enum.map(& &1.sigs)

    [
      %{tx_bytes: tx1_bytes, signatures: tx1_signs, timestamp: 10},
      %{tx_bytes: tx2_bytes, signatures: tx2_sings, timestamp: 10}
    ]
  end

  # extracts the mocked responses of the `Eth.RootChain.get_exit` for the exit events
  # all exits active (owner non-zero). This is the auxiliary, second argument that's fed into `new_exits`
  deffixture contract_statuses(exit_events) do
    exit_events
    |> Enum.map(fn %{amount: amount, currency: currency, owner: owner} -> {owner, currency, amount} end)
  end

  deffixture in_flight_exits(in_flight_exit_events) do
    Enum.map(in_flight_exit_events, &build_in_flight_exit/1)
  end

  deffixture in_flight_exits_challenges_events(in_flight_exits, competing_transactions) do
    [{tx1_hash, _}, {tx2_hash, _}] = in_flight_exits
    [competing_tx1, competing_tx2] = competing_transactions

    [
      %{
        tx_hash: tx1_hash,
        competitor_position: not_included_competitor_pos(),
        call_data: %{
          competing_tx: Transaction.encode(competing_tx1),
          competing_tx_input_index: 1,
          competing_tx_sig: <<0::520>>
        }
      },
      %{
        tx_hash: tx2_hash,
        competitor_position: not_included_competitor_pos(),
        call_data: %{
          competing_tx: Transaction.encode(competing_tx2),
          competing_tx_input_index: 2,
          competing_tx_sig: <<1::520>>
        }
      }
    ]
  end

  deffixture processor_filled(processor_empty, exit_events, contract_statuses, in_flight_exit_events) do
    {state, _} = Core.new_exits(processor_empty, exit_events, contract_statuses)
    {state, _} = Core.new_in_flight_exits(state, in_flight_exit_events)
    state
  end

  defp build_in_flight_exit(%{tx_bytes: bytes, signatures: signs, timestamp: timestamp}) do
    {:ok, raw_tx} = Transaction.decode(bytes)

    signed_tx = %Transaction.Signed{
      raw_tx: raw_tx,
      sigs: signs
    }

    {Transaction.hash(raw_tx), %InFlightExitInfo{tx: signed_tx, timestamp: timestamp}}
  end

  defp build_competitor(%{
         call_data: %{
           competing_tx: tx_bytes,
           competing_tx_input_index: input_index,
           competing_tx_sig: signature
         }
       }) do
    CompetitorInfo.build_competitor(tx_bytes, input_index, signature)
  end

  @tag fixtures: [:processor_empty, :exit_events, :contract_statuses]
  test "persist started exits and loads persisted on init", %{
    processor_empty: empty,
    exit_events: events,
    contract_statuses: contract_statuses
  } do
    values = Enum.map(events, &(Map.put(&1, :is_active, true) |> Map.delete(:utxo_pos)))
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
    alice: %{addr: alice},
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
    assert {^empty, []} = Core.new_in_flight_exits(empty, [])
    assert {^filled, []} = Core.new_exits(filled, [], [])
    assert {^filled, []} = Core.new_in_flight_exits(filled, [])

    assert {^filled, []} = Core.finalize_exits(filled, {[], []})
  end

  @tag fixtures: [:processor_empty, :alice, :state_empty, :exit_events]
  test "handles invalid exit finalization - doesn't forget and activates", %{
    processor_empty: processor,
    alice: %{addr: alice},
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
    assert {processor,
            [
              {:put, :exit_info, {@update_key1, %{is_active: true}}},
              {:put, :exit_info, {@update_key2, %{is_active: true}}}
            ]} = Core.finalize_exits(processor, two_spend)

    assert {{:error, :unchallenged_exit}, [_event1, _event2, _event3]} =
             processor
             |> Core.get_exiting_utxo_positions()
             |> Enum.map(&State.Core.utxo_exists?(&1, state_after_spend))
             |> Core.invalid_exits(processor, 12, @late_blknum)
  end

  @tag fixtures: [:processor_empty, :state_alice_deposit, :exit_events, :contract_statuses]
  test "can work with State to determine valid exits and finalize them", %{
    processor_empty: processor,
    state_alice_deposit: state,
    exit_events: [one_exit | _],
    contract_statuses: [one_status | _]
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

  @tag fixtures: [:processor_empty, :state_empty, :exit_events, :contract_statuses]
  test "can work with State to determine and notify invalid exits", %{
    processor_empty: processor,
    state_empty: state,
    exit_events: [one_exit | _],
    contract_statuses: [one_status | _]
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

  @tag fixtures: [:processor_empty, :exit_events, :contract_statuses]
  test "can challenge exits, which are then forgotten completely", %{
    processor_empty: processor,
    exit_events: events,
    contract_statuses: contract_statuses
  } do
    {processor, _} =
      processor
      |> Core.new_exits(events, contract_statuses)

    # sanity
    assert [_, _] = processor |> Core.get_exiting_utxo_positions()

    assert {processor, [{:delete, :exit_info, @update_key1}, {:delete, :exit_info, @update_key2}]} =
             processor
             |> Core.challenge_exits([
               %{utxo_pos: Utxo.Position.encode(@utxo_pos1)},
               %{utxo_pos: Utxo.Position.encode(@utxo_pos2)}
             ])

    assert [] = processor |> Core.get_exiting_utxo_positions()
  end

  @tag fixtures: [:processor_empty, :state_empty, :exit_events, :contract_statuses]
  test "can work with State to determine invalid exits entered too late", %{
    processor_empty: processor,
    state_empty: state,
    exit_events: [one_exit | _],
    contract_statuses: [one_status | _]
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

  @tag fixtures: [:processor_empty, :state_empty, :events, :contract_statuses]
  test "exits of utxos that couldn't have been seen created yet never excite events", %{
    processor_empty: processor,
    state_empty: state,
    events: [_, late_exit | _],
    contract_statuses: [_, active_status | _]
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

  @tag fixtures: [:processor_empty, :in_flight_exit_events, :in_flight_exits]
  test "properly processes new in flight exits", %{
    processor_empty: empty,
    in_flight_exit_events: events,
    in_flight_exits: ifes
  } do
    {updated_state, _} = Core.new_in_flight_exits(empty, events)

    assert ifes |> Map.new() == Core.get_in_flight_exits(updated_state)
  end

  @tag fixtures: [:processor_empty, :in_flight_exit_events, :in_flight_exits]
  test "persists in flight exits and loads persisted on init", %{
    processor_empty: empty,
    in_flight_exit_events: events,
    in_flight_exits: ifes
  } do
    updates = Enum.map(ifes, &InFlightExitInfo.make_db_update/1)
    update1 = Enum.slice(updates, 0, 1)
    update2 = Enum.slice(updates, 1, 1)

    assert {updated_state, ^update1} = Core.new_in_flight_exits(empty, Enum.slice(events, 0, 1))

    assert {final_state, ^updates} = Core.new_in_flight_exits(empty, events)

    assert {^final_state, ^update2} = Core.new_in_flight_exits(updated_state, Enum.slice(events, 1, 1))

    {:ok, ^final_state} = Core.init([], ifes, [])
  end

  #  #TODO
  #  @tag fixtures: [:processor_empty, :alice, :in_flight_exit_events]
  #  test "active piggybacks from inputs are monitored", %{
  #    processor_empty: empty,
  #    in_flight_exit_events: ife_events
  #  } do
  #    Core.new_in_flight_exits(empty, [timestamp: 1001], ife_events)
  #  end

  @tag fixtures: [:processor_filled, :in_flight_exits]
  test "persists new piggybacks", %{processor_filled: state, in_flight_exits: ifes} do
    events = Enum.map(ifes, fn {id, _} -> {id, 0} end)

    updates =
      ifes
      |> Enum.map(fn {id, ife} -> {id, InFlightExitInfo.piggyback(ife, 0)} end)
      |> Enum.map(fn {id, {:ok, ife}} -> {id, ife} end)
      |> Enum.map(&InFlightExitInfo.make_db_update/1)

    update1 = Enum.slice(updates, 0, 1)
    update2 = Enum.slice(updates, 1, 1)

    assert {updated_state, ^update1} = Core.new_piggybacks(state, Enum.slice(events, 0, 1))

    assert {final_state, ^updates} = Core.new_piggybacks(state, events)

    assert {^final_state, ^update2} = Core.new_piggybacks(updated_state, Enum.slice(events, 1, 1))
  end

  @tag fixtures: [:processor_filled, :in_flight_exits]
  test "piggybacking sanity checks", %{processor_filled: state, in_flight_exits: [{ife_id, _} | _]} do
    {^state, []} = Core.new_piggybacks(state, [])
    {^state, []} = Core.new_piggybacks(state, [{0, 0}])
    {^state, []} = Core.new_piggybacks(state, [{ife_id, 8}])

    # cannot piggyback twice the same output
    {updated_state, [_]} = Core.new_piggybacks(state, [{ife_id, 0}])
    {^updated_state, []} = Core.new_piggybacks(updated_state, [{ife_id, 0}])
  end

  @tag fixtures: [:processor_filled, :in_flight_exits_challenges_events]
  test "persists new competitors and loads persisted on init", %{
    processor_filled: state,
    in_flight_exits_challenges_events: challenges_events
  } do
    competitors = challenges_events |> Enum.map(&build_competitor/1)
    updates = Enum.map(competitors, &CompetitorInfo.make_db_update/1)

    {updated_state, db_updates} = Core.challenge_in_flight_exits(state, Enum.slice(challenges_events, 0, 1))

    assert Enum.member?(db_updates, Enum.at(updates, 0))

    {final_state, db_updates} = Core.challenge_in_flight_exits(state, challenges_events)

    assert Enum.reduce(updates, true, fn
             update, true -> Enum.member?(db_updates, update)
             _, false -> false
           end)

    assert {^final_state, db_updates} =
             Core.challenge_in_flight_exits(updated_state, Enum.slice(challenges_events, 1, 2))

    assert Enum.reduce(Enum.slice(updates, 1, 2), true, fn
             update, true -> Enum.member?(db_updates, update)
             _, false -> false
           end)

#    {:ok, ^final_state} = Core.init([], [], [])
  end

  test "new competitors sanity checks" do
  end

  #  @tag fixtures: [:processor_empty, :in_flight_exits, :in_flight_exits_challenges_events]
  #  test "can challenge an in flight exit", %{
  #    processor_empty: empty,
  #    in_flight_exits: ifes_events,
  #    in_flight_exits_challenges_events: challenges_events
  #  } do
  #    #    {state, _} = Core.new_in_flight_exits(empty, ifes_events)
  #    #
  #    #
  #    #
  #  end

  test "challenged in flight exits are not forgotten" do
  end

  test "can challenge in flight exit with an in flight transaction" do
  end

  test "can challenge in flight exit with a canonical transaction" do
  end

  test "can challenge in flight exit twice" do
  end

  test "in flight exits are found by competitor finder" do
  end

  test "competitors are found by competitor finder" do
  end

  test "forgets challenged piggybacks" do
  end
end
