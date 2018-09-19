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

defmodule OMG.API.State.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.API
  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.API.State.Core
  alias OMG.API.TestHelper, as: Test
  alias OMG.API.Utxo

  require Utxo

  @child_block_interval OMG.Eth.RootChain.get_child_block_interval() |> elem(1)
  @child_block_2 @child_block_interval * 2
  @child_block_3 @child_block_interval * 3
  @child_block_4 @child_block_interval * 4

  @empty_block_hash <<39, 51, 229, 15, 82, 110, 194, 250, 25, 162, 43, 49, 232, 237, 80, 242, 60, 209, 253, 249, 76,
                      145, 84, 237, 58, 118, 9, 162, 241, 255, 152, 31>>

  defp eth, do: Crypto.zero_address()
  defp not_eth, do: <<1::size(160)>>
  defp zero_fees_map, do: %{eth() => 0, not_eth() => 0}

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can spend deposits", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 7}, {alice, 3}]), zero_fees_map(), &1)).()
    |> success?
    |> (&Core.exec(
          Test.create_recovered([{@child_block_interval, 0, 1, alice}], eth(), [{bob, 3}]),
          zero_fees_map(),
          &1
        )).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "when spending currency must match", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})
    |> (&Core.exec(
          Test.create_recovered([{1, 0, 0, alice}], not_eth(), [{bob, 7}, {alice, 3}]),
          zero_fees_map(),
          &1
        )).()
    |> fail?(:incorrect_currency)
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "when spending inputs must have the same currency", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})
    |> Test.do_deposit(alice, %{amount: 0, currency: not_eth(), blknum: 2})
    |> (&Core.exec(
          Test.create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], eth(), [{bob, 7}, {alice, 3}]),
          zero_fees_map(),
          &1
        )).()
    |> fail?(:incorrect_currency)
  end

  @tag fixtures: [:alice, :state_empty]
  test "currency of created utxo matches currency of the input", %{alice: alice, state_empty: state} do
    state1 =
      state
      |> Test.do_deposit(alice, %{amount: 10, currency: not_eth(), blknum: 1})
      |> (&Core.exec(
            Test.create_recovered([{1, 0, 0, alice}], not_eth(), [{alice, 7}, {alice, 3}]),
            zero_fees_map(),
            &1
          )).()
      |> success?

    state1
    |> (&Core.exec(Test.create_recovered([{1000, 0, 0, alice}], eth(), [{alice, 9}]), zero_fees_map(), &1)).()
    |> fail?(:incorrect_currency)

    state1
    |> (&Core.exec(Test.create_recovered([{1000, 0, 0, alice}], not_eth(), [{alice, 3}]), zero_fees_map(), &1)).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can spend a batch of deposits", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})
    |> Test.do_deposit(bob, %{amount: 20, currency: eth(), blknum: 2})
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 10}]), zero_fees_map(), &1)).()
    |> success?
    |> (&Core.exec(Test.create_recovered([{2, 0, 0, bob}], eth(), [{alice, 20}]), zero_fees_map(), &1)).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "ignores deposits from blocks not higher than the block with the last previously received deposit", %{
    alice: alice,
    bob: bob,
    state_empty: state
  } do
    deposits = [%{owner: alice.addr, currency: eth(), amount: 20, blknum: 2}]
    assert {:ok, {_, [_, {:put, :last_deposit_child_blknum, 2}]}, state} = Core.deposit(deposits, state)

    assert {:ok, {[], []}, ^state} = Core.deposit([%{owner: bob.addr, currency: eth(), amount: 20, blknum: 1}], state)
  end

  @tag fixtures: [:bob]
  test "ignores deposits from blocks not higher than the deposit height read from db", %{bob: bob} do
    {:ok, state} = Core.extract_initial_state([], 0, 1, @child_block_interval)

    assert {:ok, {[], []}, ^state} = Core.deposit([%{owner: bob.addr, currency: eth(), amount: 20, blknum: 1}], state)
  end

  test "extract_initial_state function returns error when passed last deposit as :not_found" do
    assert {:error, :last_deposit_not_found} = Core.extract_initial_state([], 0, :not_found, @child_block_interval)
  end

  test "extract_initial_state function returns error when passed top block number as :not_found" do
    assert {:error, :top_block_number_not_found} = Core.extract_initial_state([], :not_found, 0, @child_block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can't spend nonexistent", %{alice: alice, bob: bob, state_empty: state} do
    state_deposit = state |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})

    state_deposit
    |> (&Core.exec(Test.create_recovered([{1, 1, 0, alice}], eth(), [{bob, 7}, {alice, 3}]), zero_fees_map(), &1)).()
    |> fail?(:utxo_not_found)
    |> same?(state_deposit)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit, :state_empty]
  test "amounts must add up", %{alice: alice, bob: bob, state_empty: state} do
    state = Test.do_deposit(state, alice, %{amount: 10, currency: eth(), blknum: 1})

    state =
      state
      |> (&Core.exec(
            Test.create_recovered([{1, 0, 0, alice}], eth(), [{alice, 8}, {bob, 3}]),
            # outputs exceed inputs, no fee
            %{eth() => 0},
            &1
          )).()
      |> fail?(:amounts_dont_add_up)
      |> same?(state)
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 2}, {alice, 8}]), zero_fees_map(), &1)).()
      |> success?

    state
    |> (&Core.exec(
          Test.create_recovered([{@child_block_interval, 0, 0, bob}, {@child_block_interval, 0, 1, alice}], eth(), [
            {alice, 7},
            {bob, 2}
          ]),
          # outputs exceed inputs, no fee
          %{eth() => 2},
          &1
        )).()
    |> fail?(:amounts_dont_add_up)
    |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend other people's funds", %{alice: alice, bob: bob, state_alice_deposit: state} do
    state
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, bob}], eth(), [{bob, 8}, {alice, 3}]), zero_fees_map(), &1)).()
    |> fail?(:incorrect_spender)
    |> same?(state)
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, bob}], eth(), [{alice, 10}]), zero_fees_map(), &1)).()
    |> fail?(:incorrect_spender)
    |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend spent", %{alice: alice, bob: bob, state_alice_deposit: state} do
    transactions = [
      Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 7}, {alice, 3}]),
      Test.create_recovered([{0, 0, 0, %{priv: <<>>, addr: nil}}, {1, 0, 0, alice}], eth(), [
        {bob, 7},
        {alice, 3}
      ])
    ]

    for first <- transactions,
        second <- transactions do
      state2 = state |> (&Core.exec(first, zero_fees_map(), &1)).() |> success?
      state2 |> (&Core.exec(second, zero_fees_map(), &1)).() |> fail?(:utxo_not_found) |> same?(state2)
    end
  end

  @tag fixtures: [:alice, :bob, :carol, :state_alice_deposit]
  test "can spend change and merge coins", %{
    alice: alice,
    bob: bob,
    carol: carol,
    state_alice_deposit: state
  } do
    state
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 7}, {alice, 3}]), zero_fees_map(), &1)).()
    |> success?
    |> (&Core.exec(
          Test.create_recovered([{@child_block_interval, 0, 0, bob}], eth(), [{carol, 7}]),
          zero_fees_map(),
          &1
        )).()
    |> success?
    |> (&Core.exec(
          Test.create_recovered([{@child_block_interval, 0, 1, alice}], eth(), [{carol, 3}]),
          zero_fees_map(),
          &1
        )).()
    |> success?
    |> (&Core.exec(
          Test.create_recovered([{@child_block_interval, 1, 0, carol}, {@child_block_interval, 2, 0, carol}], eth(), [
            {alice, 10}
          ]),
          zero_fees_map(),
          &1
        )).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can spend after block is formed", %{alice: alice, bob: bob, state_alice_deposit: state} do
    next_block_height = @child_block_2
    {:ok, {_, _, _}, state} = form_block_check(state, @child_block_interval)

    state
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 7}, {alice, 3}]), zero_fees_map(), &1)).()
    |> success?
    |> (&Core.exec(Test.create_recovered([{next_block_height, 0, 0, bob}], eth(), [{bob, 7}]), zero_fees_map(), &1)).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block doesn't unspend", %{alice: alice, bob: bob, state_alice_deposit: state} do
    recovered = Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 7}, {alice, 3}])

    {:ok, {_, _, _}, state} =
      state
      |> (&Core.exec(recovered, zero_fees_map(), &1)).()
      |> success?
      |> form_block_check(@child_block_interval)

    recovered |> Core.exec(zero_fees_map(), state) |> fail?(:utxo_not_found) |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "spending emits event trigger", %{alice: alice, bob: bob, state_alice_deposit: state} do
    recover = Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 7}, {alice, 3}])

    assert {:ok, {%Block{hash: block_hash, number: block_number}, [trigger], _}, _} =
             state
             |> (&Core.exec(recover, zero_fees_map(), &1)).()
             |> success?
             |> form_block_check(@child_block_interval)

    assert trigger == %{tx: recover, child_blknum: block_number, child_block_hash: block_hash}
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "every spending emits event triggers", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state =
      state
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 7}, {alice, 3}]), zero_fees_map(), &1)).()
      |> success?
      |> (&Core.exec(
            Test.create_recovered([{@child_block_interval, 0, 0, bob}], eth(), [{alice, 7}]),
            zero_fees_map(),
            &1
          )).()
      |> success?

    assert {:ok, {_, [_trigger1, _trigger2], _}, _} = form_block_check(state, @child_block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "only successful spending emits event trigger", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state
    |> (&Core.exec(Test.create_recovered([{1, 1, 0, alice}], eth(), [{bob, 7}, {alice, 3}]), zero_fees_map(), &1)).()
    |> same?(state)

    assert {:ok, {_, [], _}, _} = form_block_check(state, @child_block_interval)
  end

  @tag fixtures: [:alice, :state_empty]
  test "deposits emit event triggers, they don't leak into next block", %{
    alice: alice,
    state_empty: state
  } do
    assert {:ok, {[trigger], _}, state} =
             Core.deposit([%{owner: alice, currency: eth(), amount: 4, blknum: @child_block_interval}], state)

    assert trigger == %{deposit: %{owner: alice, amount: 4}}
    assert {:ok, {_, [], _}, _} = form_block_check(state, @child_block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "empty blocks emit empty event triggers", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state =
      state
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 7}, {alice, 3}]), zero_fees_map(), &1)).()
      |> success?

    assert {:ok, {_, [_trigger], _}, state} = form_block_check(state, @child_block_interval)

    assert {:ok, {_, [], _}, _} = form_block_check(state, @child_block_interval)
  end

  @tag fixtures: [:stable_alice, :stable_bob, :state_stable_alice_deposit]
  test "forming block puts all transactions in a block", %{
    stable_alice: alice,
    stable_bob: bob,
    state_stable_alice_deposit: state
  } do
    # odd number of transactions, just in case
    recovered_tx_1 = Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 7}, {alice, 3}])
    recovered_tx_2 = Test.create_recovered([{@child_block_interval, 0, 0, bob}], eth(), [{alice, 2}, {bob, 5}])
    recovered_tx_3 = Test.create_recovered([{@child_block_interval, 0, 1, alice}], eth(), [{alice, 2}, {bob, 1}])

    state =
      state
      |> (&Core.exec(recovered_tx_1, zero_fees_map(), &1)).()
      |> success?
      |> (&Core.exec(recovered_tx_2, zero_fees_map(), &1)).()
      |> success?
      |> (&Core.exec(recovered_tx_3, zero_fees_map(), &1)).()
      |> success?

    assert {:ok,
            {%Block{
               transactions: [block_tx1, block_tx2, _third_tx],
               hash: block_hash,
               number: @child_block_interval
             }, _, _}, _} = form_block_check(state, @child_block_interval)

    # precomputed fixed hash to check compliance with hashing algo
    assert block_hash |> Base.encode16(case: :lower) ==
             "d3e45b686ecb5d7c4580192861088c0add6246a0f4dc8f6eebd2ae8783945eaa"

    # Check that contents of the block can be recovered again to original txs
    assert {:ok, ^recovered_tx_1} = API.Core.recover_tx(block_tx1)
    assert {:ok, ^recovered_tx_2} = API.Core.recover_tx(block_tx2)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block empty block after a non-empty block", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state =
      state
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 7}, {alice, 3}]), zero_fees_map(), &1)).()
      |> success?

    {:ok, {_, _, _}, state} = form_block_check(state, @child_block_interval)
    expected_block = empty_block(@child_block_2)

    assert {:ok, {^expected_block, _, _}, _} = form_block_check(state, @child_block_interval)
  end

  @tag fixtures: [:state_empty]
  test "no pending transactions at start (no events, empty block, no db updates)", %{state_empty: state} do
    expected_block = empty_block()

    assert {:ok, {^expected_block, [], [{:put, :block, _}, {:put, :child_top_block_number, @child_block_interval}]},
            _state} = form_block_check(state, @child_block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "spending produces db updates, that don't leak to next block", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    {:ok, {_, _, db_updates}, state} =
      state
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 7}, {alice, 3}]), zero_fees_map(), &1)).()
      |> success?
      |> form_block_check(@child_block_interval)

    assert [
             {:put, :utxo, new_utxo1},
             {:put, :utxo, new_utxo2},
             {:delete, :utxo, {1, 0, 0}},
             {:put, :block, _},
             {:put, :child_top_block_number, @child_block_interval}
           ] = db_updates

    assert new_utxo1 == {{@child_block_interval, 0, 0}, %{owner: bob.addr, currency: eth(), amount: 7}}
    assert new_utxo2 == {{@child_block_interval, 0, 1}, %{owner: alice.addr, currency: eth(), amount: 3}}

    assert {:ok, {_, _, [{:put, :block, _}, {:put, :child_top_block_number, @child_block_2}]}, state} =
             form_block_check(state, @child_block_interval)

    # check double inputey-spends
    {:ok, {_, _, db_updates2}, state} =
      state
      |> (&Core.exec(
            Test.create_recovered([{@child_block_interval, 0, 0, bob}, {@child_block_interval, 0, 1, alice}], eth(), [
              {bob, 10}
            ]),
            zero_fees_map(),
            &1
          )).()
      |> success?
      |> form_block_check(@child_block_interval)

    assert [
             {:put, :utxo, new_utxo},
             {:delete, :utxo, {@child_block_interval, 0, 0}},
             {:delete, :utxo, {@child_block_interval, 0, 1}},
             {:put, :block, _},
             {:put, :child_top_block_number, @child_block_3}
           ] = db_updates2

    assert new_utxo == {{@child_block_3, 0, 0}, %{owner: bob.addr, currency: eth(), amount: 10}}

    assert {:ok, {_, _, [{:put, :block, _}, {:put, :child_top_block_number, @child_block_4}]}, _} =
             form_block_check(state, @child_block_interval)
  end

  @tag fixtures: [:alice, :state_empty]
  test "depositing produces db updates, that don't leak to next block", %{
    alice: alice,
    state_empty: state
  } do
    assert {:ok, {_, [utxo_update, height_update]}, state} =
             Core.deposit([%{owner: alice.addr, currency: eth(), amount: 10, blknum: 1}], state)

    assert utxo_update == {:put, :utxo, {{1, 0, 0}, %{owner: alice.addr, currency: eth(), amount: 10}}}
    assert height_update == {:put, :last_deposit_child_blknum, 1}

    assert {:ok, {_, _, [{:put, :block, _}, {:put, :child_top_block_number, @child_block_interval}]}, _} =
             form_block_check(state, @child_block_interval)
  end

  @tag fixtures: [:alice]
  test "utxos get initialized by query result from db and are spendable", %{alice: alice} do
    {:ok, state} =
      Core.extract_initial_state(
        [{{1, 0, 0}, %{amount: 10, currency: eth(), owner: alice.addr}}],
        0,
        1,
        @child_block_interval
      )

    state
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{alice, 7}, {alice, 3}]), zero_fees_map(), &1)).()
    |> success?
  end

  @tag fixtures: [:alice, :bob]
  test "all utxos get initialized by query result from db and are spendable", %{alice: alice, bob: bob} do
    {:ok, state} =
      Core.extract_initial_state(
        [
          {{1, 0, 0}, %{amount: 10, currency: eth(), owner: alice.addr}},
          {{1001, 10, 1}, %{amount: 8, currency: eth(), owner: bob.addr}}
        ],
        1000,
        1,
        @child_block_interval
      )

    state
    |> (&Core.exec(
          Test.create_recovered([{1, 0, 0, alice}, {1001, 10, 1, bob}], eth(), [{alice, 15}, {alice, 3}]),
          zero_fees_map(),
          &1
        )).()
    |> success?
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "spends utxo when exiting", %{alice: alice, state_alice_deposit: state} do
    state =
      state
      |> (&Core.exec(
            Test.create_recovered([{1, 0, 0, alice}], eth(), [{alice, 7}, {alice, 3}]),
            zero_fees_map(),
            &1
          )).()
      |> success?

    expected_owner = alice.addr

    utxo_pos_exit_1 = Utxo.position(@child_block_interval, 0, 0)
    utxo_pos_exit_2 = Utxo.position(@child_block_interval, 0, 1)

    utxo_pos_exit_1_encode = utxo_pos_exit_1 |> Utxo.Position.encode()
    utxo_pos_exit_2_encode = utxo_pos_exit_2 |> Utxo.Position.encode()

    {:ok,
     {[
        %{exit: %{owner: ^expected_owner, utxo_pos: ^utxo_pos_exit_1}},
        %{exit: %{owner: ^expected_owner, utxo_pos: ^utxo_pos_exit_2}}
      ], [{:delete, :utxo, {@child_block_interval, 0, 0}}, {:delete, :utxo, {@child_block_interval, 0, 1}}]},
     state} =
      [
        %{owner: alice.addr, utxo_pos: utxo_pos_exit_1_encode},
        %{owner: alice.addr, utxo_pos: utxo_pos_exit_2_encode}
      ]
      |> Core.exit_utxos(state)

    state
    |> (&Core.exec(
          Test.create_recovered([{@child_block_interval, 0, 0, alice}], eth(), [{alice, 7}]),
          zero_fees_map(),
          &1
        )).()
    |> fail?(:utxo_not_found)
    |> same?(state)
    |> (&Core.exec(
          Test.create_recovered([{@child_block_interval, 0, 1, alice}], eth(), [{alice, 3}]),
          zero_fees_map(),
          &1
        )).()
    |> fail?(:utxo_not_found)
    |> same?(state)
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "does not change when exiting spent utxo", %{alice: alice, state_alice_deposit: state} do
    state =
      state
      |> (&Core.exec(
            Test.create_recovered([{1, 0, 0, alice}], eth(), [{alice, 7}, {alice, 3}]),
            zero_fees_map(),
            &1
          )).()
      |> success?

    {:ok, {[], []}, ^state} =
      [%{owner: alice.addr, utxo_pos: Utxo.position(1, 0, 0) |> Utxo.Position.encode()}]
      |> Core.exit_utxos(state)
  end

  @tag fixtures: [:state_empty]
  test "does not change when exiting non-existent utxo", %{state_empty: state} do
    {:ok, {[], []}, ^state} =
      [%{owner: "owner", utxo_pos: Utxo.position(1, 0, 0) |> Utxo.Position.encode()}]
      |> Core.exit_utxos(state)
  end

  @tag fixtures: [:alice, :state_empty]
  test "tells if utxo exists", %{alice: alice, state_empty: state} do
    assert not Core.utxo_exists?(%{utxo_pos: Utxo.position(1, 0, 0) |> Utxo.Position.encode()}, state)

    state = state |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})
    assert Core.utxo_exists?(%{utxo_pos: Utxo.position(1, 0, 0) |> Utxo.Position.encode()}, state)

    state =
      state
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{alice, 10}]), zero_fees_map(), &1)).()
      |> success?

    assert not Core.utxo_exists?(%{utxo_pos: Utxo.position(1, 0, 0) |> Utxo.Position.encode()}, state)
  end

  @tag fixtures: [:state_empty]
  test "Getting current block height on empty state", %{state_empty: state} do
    blknum = Core.get_current_child_block_height(state)

    assert blknum == @child_block_interval
  end

  @tag fixtures: [:state_empty]
  test "Getting current block height with one formed block", %{state_empty: state} do
    {:ok, {_, _, _}, newstate} = state |> form_block_check(@child_block_interval)
    blknum = Core.get_current_child_block_height(newstate)

    assert blknum == @child_block_interval + @child_block_interval
  end

  describe "Transaction with fees" do
    @tag fixtures: [:alice, :bob, :state_empty]
    test "Inputs sums up exactly to outputs plus fee", %{alice: alice, bob: bob, state_empty: state} do
      # outputs: 5 + 3 + 2 == 10 <- inputs
      fee = %{eth() => 2}

      state
      |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 5}, {alice, 3}]), fee, &1)).()
      |> success?
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "Inputs exceeds outputs plus fee", %{alice: alice, bob: bob, state_empty: state} do
      # outputs: 4 + 3 + 2 < 10 <- inputs
      fee = %{eth() => 2}

      state
      |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 4}, {alice, 3}]), fee, &1)).()
      |> success?
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "Inputs are not sufficient for outputs plus fee", %{alice: alice, bob: bob, state_empty: state} do
      # outputs: 6 + 3 + 2 > 10 <- inputs
      fee = %{eth() => 2}

      state
      |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 6}, {alice, 3}]), fee, &1)).()
      |> fail?(:amounts_dont_add_up)
    end
  end

  @tag fixtures: [:alice, :state_empty]
  test "Output can have a zero value; can't be used as input though", %{alice: alice, state_empty: state} do
    fee = %{eth() => 0}

    state
    |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{alice, 8}, {alice, 0}]), fee, &1)).()
    |> success?
    |> (&Core.exec(Test.create_recovered([{1000, 0, 1, alice}], eth(), [{alice, 0}]), fee, &1)).()
    |> fail?(:utxo_not_found)
  end

  @tag fixtures: [:alice, :state_empty]
  test "Output with zero value does not change oindex of other outputs", %{alice: alice, state_empty: state} do
    fee = %{eth() => 0}

    state
    |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{alice, 0}, {alice, 8}]), fee, &1)).()
    |> success?
    |> (&Core.exec(Test.create_recovered([{1000, 0, 1, alice}], eth(), [{alice, 1}]), fee, &1)).()
    |> success?
  end

  @tag fixtures: [:alice, :state_empty]
  test "Output with zero value will not be written to DB", %{alice: alice, state_empty: state} do
    fee = %{eth() => 2}

    state =
      state
      |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), [{alice, 0}]), fee, &1)).()
      |> success?

    {_, {_, _, db_updates}, _} = Core.form_block(1000, state)
    assert [] = Enum.filter(db_updates, &match?({:put, :utxo, _}, &1))
  end

  @tag fixtures: [:alice, :state_empty]
  test "Transaction can have no outputs", %{alice: alice, state_empty: state} do
    fee = %{eth() => 2}

    state
    |> Test.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 1})
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], eth(), []), fee, &1)).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "Does not allow executing transactions with input utxos from the future", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    fee = %{eth() => 0}

    future_deposit_blknum = @child_block_interval + 1
    state = Test.do_deposit(state, alice, %{amount: 10, currency: eth(), blknum: future_deposit_blknum})

    # input utxo blknum is greater than state's blknum
    state
    |> (&Core.exec(
          Test.create_recovered([{future_deposit_blknum, 0, 0, alice}], eth(), [
            {bob, 6},
            {alice, 4}
          ]),
          fee,
          &1
        )).()
    |> fail?(:input_utxo_ahead_of_state)

    state
    |> (&Core.exec(
          Test.create_recovered(
            [{1, 0, 0, alice}, {future_deposit_blknum, 0, 0, alice}],
            eth(),
            [{bob, 6}, {alice, 4}]
          ),
          fee,
          &1
        )).()
    |> fail?(:input_utxo_ahead_of_state)

    # when non-existent input comes with a blknum of the current block fail with :utxo_not_found
    state
    |> (&Core.exec(
          Test.create_recovered([{@child_block_interval, 1, 0, alice}], eth(), [
            {bob, 6},
            {alice, 4}
          ]),
          fee,
          &1
        )).()
    |> fail?(:utxo_not_found)
  end

  defp success?(result) do
    assert {:ok, _, state} = result
    state
  end

  defp fail?(result, expected_error) do
    assert {{:error, ^expected_error}, state} = result
    state
  end

  defp same?({{:error, _someerror}, state}, expected_state) do
    assert expected_state == state
    state
  end

  defp same?(state, expected_state) do
    assert expected_state == state
    state
  end

  defp empty_block(number \\ @child_block_interval) do
    %Block{transactions: [], hash: @empty_block_hash, number: number}
  end

  # used to check the invariants in form_block
  # use this throughout this test module instead of Core.form_block
  defp form_block_check(state, child_block_interval) do
    {_, {block, _, db_updates}, _} = result = Core.form_block(child_block_interval, state)

    # check if block returned and sent to db_updates is the same
    assert Enum.member?(db_updates, {:put, :block, block})
    # check if that's the only db_update for block
    is_block_put? = fn {operation, type, _} -> operation == :put && type == :block end
    assert Enum.count(db_updates, is_block_put?) == 1

    result
  end
end
