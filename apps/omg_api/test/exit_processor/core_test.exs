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

defmodule OMG.API.ExitProcessor.CoreTest do
  @moduledoc """
  Test of the logic of exit processor - not losing exits from persistence, emitting events, talking to API.State.Core
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.API.Fixtures

  alias OMG.API.Crypto
  alias OMG.API.ExitProcessor.Core
  alias OMG.API.State
  alias OMG.API.Utxo
  alias OMG.Watcher.Eventer.Event

  require Utxo

  @eth Crypto.zero_address()
  @not_eth <<1::size(160)>>

  @utxo_pos1 Utxo.Position.decode(28_000_000_000_000)
  @utxo_pos2 Utxo.Position.decode(10_000_000_001)

  deffixture empty_state() do
    {:ok, empty} = Core.init([])
    empty
  end

  deffixture events(alice) do
    %{addr: alice} = alice

    [
      %{amount: 7, currency: @eth, owner: alice, utxo_pos: Utxo.Position.encode(@utxo_pos1), eth_height: 2},
      %{amount: 9, currency: @not_eth, owner: alice, utxo_pos: Utxo.Position.encode(@utxo_pos2), eth_height: 4}
    ]
  end

  # extracts the mocked responses of the Eth.RootChain.get_exit for the exit events - all exits active (owner non-zero)
  deffixture contract_statuses(events) do
    events
    |> Enum.map(fn %{amount: amount, currency: currency, owner: owner} -> {owner, currency, amount} end)
  end

  deffixture filled_state(empty_state, events, contract_statuses) do
    {state, _} = Core.new_exits(empty_state, events, contract_statuses)
    state
  end

  @tag fixtures: [:empty_state, :alice, :events, :contract_statuses]
  test "persist started exits and loads persisted on init", %{
    empty_state: empty,
    events: events,
    contract_statuses: contract_statuses
  } do
    keys = [@utxo_pos1, @utxo_pos2]
    # FIXME: remove
    # values = [{7, @eth, alice, 2, true}, {9, @not_eth, alice, 4, true}]
    values = Enum.map(events, &(Map.put(&1, :is_active, true) |> Map.delete(:utxo_pos)))
    updates = Enum.zip([[:put, :put], [:exit_info, :exit_info], Enum.zip(keys, values)])
    update1 = Enum.slice(updates, 0, 1)
    update2 = Enum.slice(updates, 1, 1)

    assert {state2, ^update1} = Core.new_exits(empty, Enum.slice(events, 0, 1), Enum.slice(contract_statuses, 0, 1))
    assert {final_state, ^updates} = Core.new_exits(empty, events, contract_statuses)

    assert {^final_state, ^update2} =
             Core.new_exits(state2, Enum.slice(events, 1, 1), Enum.slice(contract_statuses, 1, 1))

    {:ok, ^final_state} = Core.init(Enum.zip(keys, values))
  end

  @tag fixtures: [:empty_state, :filled_state]
  test "can process empty new exits or empty finalizations", %{empty_state: empty, filled_state: filled} do
    assert {^empty, []} = Core.new_exits(empty, [], [])
    assert {^filled, []} = Core.new_exits(filled, [], [])
    assert {^filled, [], []} = Core.finalize_exits(filled, [])
  end

  @tag fixtures: [:filled_state]
  test "forgets finalized exits from persistence and spends in state", %{filled_state: state} do
    assert {_, [{:delete, :exit_info, @utxo_pos1}], [@utxo_pos1]} =
             Core.finalize_exits(state, [%{utxo_pos: Utxo.Position.encode(@utxo_pos1)}])

    assert {_, [{:delete, :exit_info, @utxo_pos1}, {:delete, :exit_info, @utxo_pos2}], [@utxo_pos1, @utxo_pos2]} =
             Core.finalize_exits(state, [
               %{utxo_pos: Utxo.Position.encode(@utxo_pos1)},
               %{utxo_pos: Utxo.Position.encode(@utxo_pos2)}
             ])
  end

  @tag fixtures: [:empty_state, :alice, :state_alice_deposit]
  test "can work with State to determine valid exits and finalize them", %{
    empty_state: processor_state,
    alice: %{addr: alice},
    state_alice_deposit: state
  } do
    exiting_position = Utxo.position(1, 0, 0)

    # FIXME: (elsewehere) add sanity checks for new_exits w/ tests

    {processor_state, _} =
      processor_state
      |> Core.new_exits(
        [
          %{
            amount: 10,
            currency: @eth,
            owner: alice,
            utxo_pos: Utxo.Position.encode(exiting_position),
            eth_height: 2
          }
        ],
        [{alice, @eth, 10}]
      )

    assert {[], :chain_ok} =
             processor_state
             |> Core.get_exiting_utxo_positions()
             |> Enum.map(&State.Core.utxo_exists?(&1, state))
             |> Core.invalid_exits(processor_state, 5)

    # FIXME: we should make exit_utxos return whether the utxo existed or not and assert on that, instead of just `:ok`
    # FIXME: also the utxo position encoding should be fixed and this test unblocked
    # {_, _, to_finalize} = Core.finalize_exits(processor_state, [%{utxo_pos: Utxo.Position.encode(exiting_position)}])
    # assert :ok = State.Core.exit_utxos(to_finalize, state)
  end

  @tag fixtures: [:empty_state, :alice, :state_empty]
  test "can work with State to determine and notify invalid exits", %{
    empty_state: processor_state,
    alice: %{addr: alice},
    state_empty: state
  } do
    exiting_position = Utxo.Position.encode(Utxo.position(1, 0, 0))

    {processor_state, _} =
      processor_state
      |> Core.new_exits(
        [
          %{
            amount: 10,
            currency: @eth,
            owner: alice,
            utxo_pos: exiting_position,
            eth_height: 2
          }
        ],
        [{alice, @eth, 10}]
      )

    assert {[%Event.InvalidExit{utxo_pos: ^exiting_position}], :chain_ok} =
             processor_state
             |> Core.get_exiting_utxo_positions()
             # FIXME: when ExitProcessor takes over, there shouldn't be that encode
             |> Enum.map(&State.Core.utxo_exists?(&1, state))
             |> Core.invalid_exits(processor_state, 5)
  end

  @tag fixtures: [:empty_state, :alice, :state_empty]
  test "can work with State to determine invalid exits entered too late", %{
    empty_state: processor_state,
    alice: %{addr: alice},
    state_empty: state
  } do
    exiting_position = Utxo.Position.encode(Utxo.position(1, 0, 0))

    {processor_state, _} =
      processor_state
      |> Core.new_exits(
        [
          %{
            amount: 10,
            currency: @eth,
            owner: alice,
            utxo_pos: exiting_position,
            eth_height: 2
          }
        ],
        [{alice, @eth, 10}]
      )

    assert {[%Event.UnchallengedExit{utxo_pos: ^exiting_position}, %Event.InvalidExit{utxo_pos: ^exiting_position}],
            {:needs_stopping, :unchallenged_exit}} =
             processor_state
             |> Core.get_exiting_utxo_positions()
             # FIXME: when ExitProcessor takes over, there shouldn't be that encode
             |> Enum.map(&State.Core.utxo_exists?(&1, state))
             |> Core.invalid_exits(processor_state, 13)

    # FIXME: assert Eventer likes these events
    # FIXME: new test - valid exits are fine even being old
  end

  @tag fixtures: [:empty_state, :alice, :state_empty]
  test "invalid exits that have been witnessed already inactive don't excite events", %{
    empty_state: processor_state,
    alice: %{addr: alice},
    state_empty: state
  } do
    exiting_position = Utxo.position(1, 0, 0)

    {processor_state, _} =
      processor_state
      |> Core.new_exits(
        [
          %{
            amount: 10,
            currency: @eth,
            owner: alice,
            utxo_pos: Utxo.Position.encode(exiting_position),
            eth_height: 2
          }
        ],
        [{Crypto.zero_address(), @eth, 10}]
      )

    assert {[], :chain_ok} =
             processor_state
             |> Core.get_exiting_utxo_positions()
             # FIXME: when ExitProcessor takes over, there shouldn't be that encode
             |> Enum.map(&State.Core.utxo_exists?(&1, state))
             |> Core.invalid_exits(processor_state, 13)

    # FIXME: assert Eventer likes these events
  end

  @tag fixtures: [:empty_state]
  test "empty processor returns no exiting utxo positions", %{empty_state: empty} do
    assert [] = Core.get_exiting_utxo_positions(empty)
  end
end
