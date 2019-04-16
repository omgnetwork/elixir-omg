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

defmodule OMG.Watcher.ExitProcessor.Core.StateInteractionTest do
  @moduledoc """
  Test talking to OMG.State.Core
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.Fixtures

  alias OMG.State
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core

  require Utxo

  import OMG.Watcher.ExitProcessor.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @early_blknum 1_000
  @late_blknum 10_000

  @utxo_pos1 Utxo.position(2, 0, 0)
  @utxo_pos2 Utxo.position(@late_blknum - 1_000, 0, 1)

  @tag fixtures: [:processor_empty, :state_empty, :alice]
  test "can work with State to determine and notify invalid exits", %{
    processor_empty: processor,
    state_empty: state,
    alice: alice
  } do
    exiting_position = Utxo.Position.encode(@utxo_pos1)

    standard_exit_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    processor = processor |> start_se_from(standard_exit_tx, @utxo_pos1)

    assert {:ok, [%Event.InvalidExit{utxo_pos: ^exiting_position}]} =
             %ExitProcessor.Request{eth_height_now: 5, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.check_validity(processor)
  end

  @tag fixtures: [:processor_empty, :state_empty, :alice]
  test "can work with State to determine invalid exits entered too late", %{
    processor_empty: processor,
    state_empty: state,
    alice: alice
  } do
    exiting_position = Utxo.Position.encode(@utxo_pos1)
    standard_exit_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    processor = processor |> start_se_from(standard_exit_tx, @utxo_pos1)

    assert {{:error, :unchallenged_exit},
            [%Event.UnchallengedExit{utxo_pos: ^exiting_position}, %Event.InvalidExit{utxo_pos: ^exiting_position}]} =
             %ExitProcessor.Request{eth_height_now: 13, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.check_validity(processor)
  end

  @tag fixtures: [:processor_empty, :state_empty, :alice]
  test "invalid exits that have been witnessed already inactive don't excite events", %{
    processor_empty: processor,
    state_empty: state,
    alice: alice
  } do
    standard_exit_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    processor = processor |> start_se_from(standard_exit_tx, @utxo_pos1, inactive: true)

    assert {:ok, []} =
             %ExitProcessor.Request{eth_height_now: 13, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.check_validity(processor)
  end

  @tag fixtures: [:processor_empty, :state_empty, :alice]
  test "exits of utxos that couldn't have been seen created yet never excite events", %{
    processor_empty: processor,
    state_empty: state,
    alice: alice
  } do
    standard_exit_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    processor = processor |> start_se_from(standard_exit_tx, Utxo.position(@late_blknum, 0, 0))

    assert {:ok, []} =
             %ExitProcessor.Request{eth_height_now: 13, blknum_now: @early_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.check_validity(processor)
  end

  @tag fixtures: [:processor_empty, :alice, :state_empty]
  test "handles invalid exit finalization - doesn't forget and causes a byzantine chain report", %{
    processor_empty: processor,
    state_empty: state,
    alice: alice
  } do
    standard_exit_tx1 = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    standard_exit_tx2 = TestHelper.create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 10}, {alice, 10}])

    processor =
      processor
      |> start_se_from(standard_exit_tx1, @utxo_pos1)
      |> start_se_from(standard_exit_tx2, @utxo_pos2, eth_height: 4)

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
             |> Core.check_validity(processor)
  end

  @tag fixtures: [:processor_empty, :state_empty, :alice]
  test "can work with State to determine valid exits and finalize them", %{
    processor_empty: processor,
    state_empty: state_empty,
    alice: alice
  } do
    state = state_empty |> TestHelper.do_deposit(alice, %{amount: 10, currency: @eth, blknum: 2})

    standard_exit_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    processor = processor |> start_se_from(standard_exit_tx, @utxo_pos1)

    assert {:ok, []} =
             %ExitProcessor.Request{eth_height_now: 5, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.check_validity(processor)

    # go into the future - old exits work the same
    assert {:ok, []} =
             %ExitProcessor.Request{eth_height_now: 105, blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.check_validity(processor)

    # exit validly finalizes and continues to not emit any events
    {:ok, {_, spends}, _} = [@utxo_pos1] |> prepare_exit_finalizations() |> State.Core.exit_utxos(state)
    assert {processor, _, [{:delete, :exit_info, {2, 0, 0}}]} = Core.finalize_exits(processor, spends)

    assert %ExitProcessor.Request{utxos_to_check: []} =
             Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)
  end

  @tag fixtures: [:alice, :processor_empty, :state_empty]
  test "only asking for spends concerning ifes",
       %{
         alice: alice,
         processor_empty: processor,
         state_empty: state_empty
       } do
    processor = processor |> start_ife_from(TestHelper.create_recovered([{1, 0, 0, alice}], []))

    state = state_empty |> TestHelper.do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
    comp = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 8}])

    # first sanity-check as if the utxo was not spent yet
    assert %{utxos_to_check: utxos_to_check, utxo_exists_result: utxo_exists_result, spends_to_get: spends_to_get} =
             %ExitProcessor.Request{blknum_now: @late_blknum}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.determine_spends_to_get(processor)

    assert {Utxo.position(1, 0, 0), false} not in Enum.zip(utxos_to_check, utxo_exists_result)
    assert Utxo.position(1, 0, 0) not in spends_to_get

    # spend and see that Core now requests the relevant utxo checks and spends to get
    {:ok, _, state} = State.Core.exec(state, comp, %{@eth => 0})
    {:ok, {block, _, _}, state} = State.Core.form_block(1000, state)

    assert %{utxos_to_check: utxos_to_check, utxo_exists_result: utxo_exists_result, spends_to_get: spends_to_get} =
             %ExitProcessor.Request{blknum_now: @late_blknum, blocks_result: [block]}
             |> Core.determine_utxo_existence_to_get(processor)
             |> mock_utxo_exists(state)
             |> Core.determine_spends_to_get(processor)

    assert {Utxo.position(1, 0, 0), false} in Enum.zip(utxos_to_check, utxo_exists_result)
    assert Utxo.position(1, 0, 0) in spends_to_get
  end

  defp mock_utxo_exists(%ExitProcessor.Request{utxos_to_check: positions} = request, state) do
    %{request | utxo_exists_result: positions |> Enum.map(&State.Core.utxo_exists?(&1, state))}
  end

  defp prepare_exit_finalizations(utxo_positions), do: Enum.map(utxo_positions, &%{utxo_pos: Utxo.Position.encode(&1)})

  # FIXME: stop being a fixture
  deffixture processor_empty() do
    {:ok, empty} = Core.init([], [], [])
    empty
  end
end
