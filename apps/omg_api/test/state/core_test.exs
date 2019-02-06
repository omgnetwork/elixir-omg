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
  @moduledoc """
  Tests functional behaviors of our high-throughput ledger being `OMG.API.State.Core`. For test related to state
  persistence of this see `OMG.API.State.PersistenceTest`
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.API
  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.API.State.Core
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo

  import OMG.API.TestHelper

  require Utxo

  @eth Crypto.zero_address()
  @not_eth <<1::size(160)>>
  @zero_fees %{@eth => 0, @not_eth => 0}
  @interval OMG.Eth.RootChain.get_child_block_interval() |> elem(1)
  @blknum1 @interval
  @blknum2 @interval * 2

  @empty_block_hash <<119, 106, 49, 219, 52, 161, 160, 167, 202, 175, 134, 44, 255, 223, 255, 23, 137, 41, 127, 250,
                      220, 56, 11, 211, 211, 146, 129, 211, 64, 171, 211, 173>>

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can spend deposits", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
    |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}]), @zero_fees)
    |> success?
    |> Core.exec(create_recovered([{@blknum1, 0, 1, alice}], @eth, [{bob, 3}]), @zero_fees)
    |> success?
  end

  describe "Transaction amounts and fees" do
    @tag fixtures: [:alice, :state_empty]
    test "output currencies must be included in input currencies", %{alice: alice, state_empty: state} do
      state1 =
        state
        |> do_deposit(alice, %{amount: 10, currency: @not_eth, blknum: 1})
        |> Core.exec(create_recovered([{1, 0, 0, alice}], @not_eth, [{alice, 7}, {alice, 3}]), @zero_fees)
        |> success?

      state1
      |> Core.exec(create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 9}]), @zero_fees)
      |> fail?(:amounts_do_not_add_up)

      state1
      |> Core.exec(create_recovered([{1000, 0, 0, alice}], [{alice, @eth, 9}, {alice, @not_eth, 3}]), @zero_fees)
      |> fail?(:amounts_do_not_add_up)

      state1
      |> Core.exec(create_recovered([{1000, 0, 0, alice}], [{alice, @not_eth, 3}]), @zero_fees)
      |> success?
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "amounts from multiple inputs must add up", %{alice: alice, bob: bob, state_empty: state} do
      state = do_deposit(state, alice, %{amount: 10, currency: @eth, blknum: 1})

      # outputs exceed inputs, no fee
      state =
        state
        |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 8}, {bob, 3}]), @zero_fees)
        |> fail?(:amounts_do_not_add_up)
        |> same?(state)
        |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 2}, {alice, 8}]), @zero_fees)
        |> success?

      # outputs exceed inputs, with fee
      state
      |> Core.exec(create_recovered([{@blknum1, 0, 0, bob}, {@blknum1, 0, 1, alice}], @eth, [{alice, 7}, {bob, 2}]), %{
        @eth => 2
      })
      |> fail?(:amounts_do_not_add_up)
      |> same?(state)
      |> Core.exec(
        create_recovered([{@blknum1, 0, 0, bob}, {@blknum1, 0, 1, alice}], @eth, [{alice, 9}, {bob, 2}]),
        @zero_fees
      )
      |> fail?(:amounts_do_not_add_up)
      |> same?(state)
      |> Core.exec(
        create_recovered([{@blknum1, 0, 0, bob}, {@blknum1, 0, 1, alice}], @eth, [{alice, 7}, {bob, 2}]),
        @zero_fees
      )
      |> success?()
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "Inputs exceeds outputs plus fee", %{alice: alice, bob: bob, state_empty: state} do
      # outputs: 4 + 3 + 2 < 10 <- inputs
      fee = %{@eth => 2}

      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 4}, {alice, 3}]), fee)
      |> success?
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "Inputs sums up exactly to outputs plus fee", %{alice: alice, bob: bob, state_empty: state} do
      # outputs: 5 + 3 + 2 == 10 <- inputs
      fee = %{@eth => 2}

      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 5}, {alice, 3}]), fee)
      |> success?
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "Inputs are not sufficient for outputs plus fee", %{alice: alice, bob: bob, state_empty: state} do
      # outputs: 6 + 3 + 2 > 10 <- inputs
      fee = %{@eth => 2}

      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}]), fee)
      |> fail?(:amounts_do_not_add_up)
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "respects fees for transactions with mixed currencies", %{
      alice: alice,
      bob: bob,
      state_empty: state
    } do
      fees = %{@eth => 1, @not_eth => 1}
      not_fee_token = <<2::160>>

      assert not_fee_token not in [@eth, @not_eth]

      state =
        state
        |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
        |> do_deposit(alice, %{amount: 10, currency: @not_eth, blknum: 2})
        |> do_deposit(alice, %{amount: 10, currency: not_fee_token, blknum: 3})

      # fee is paid in the same currency as an output
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, @eth, 10}, {bob, @not_eth, 1}]), fees)
      |> success?

      # fee is paid in different currency then outputs
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, @eth, 9}, {bob, @eth, 1}]), fees)
      |> success?

      # fee is paid from input not transferred by transaction
      state
      |> Core.exec(
        create_recovered([{1, 0, 0, alice}, {3, 0, 0, alice}], [{bob, not_fee_token, 9}, {bob, not_fee_token, 1}]),
        %{@eth => 10}
      )
      |> success?

      # fee is respected but amounts don't add up
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, @eth, 10}, {bob, @eth, 1}]), fees)
      |> fail?(:amounts_do_not_add_up)
      # fee is not respected
      |> Core.exec(create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, @eth, 10}, {bob, @not_eth, 10}]), fees)
      |> fail?(:amounts_do_not_add_up)
      # transaction transferring only not fee currency still is obliged to fee
      |> Core.exec(create_recovered([{3, 0, 0, alice}], not_fee_token, [{bob, 3}, {alice, 7}]), fees)
      |> fail?(:amounts_do_not_add_up)
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "can spend deposits with mixed currencies", %{
      alice: alice,
      bob: bob,
      state_empty: state
    } do
      state
      |> do_deposit(alice, %{amount: 1, currency: @eth, blknum: 1})
      |> do_deposit(alice, %{amount: 2, currency: @not_eth, blknum: 2})
      |> Core.exec(
        create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, @eth, 1}, {bob, @not_eth, 2}]),
        @zero_fees
      )
      |> success?
    end
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can spend a batch of deposits", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
    |> do_deposit(bob, %{amount: 20, currency: @eth, blknum: 2})
    |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 10}]), @zero_fees)
    |> success?
    |> Core.exec(create_recovered([{2, 0, 0, bob}], @eth, [{alice, 20}]), @zero_fees)
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can't spend when signature order does not match input order", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
    |> do_deposit(bob, %{amount: 20, currency: @eth, blknum: 2})
    |> Core.exec(create_recovered([{1, 0, 0, bob}, {2, 0, 0, alice}], @eth, [{bob, 10}]), @zero_fees)
    |> fail?(:unauthorized_spent)
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "ignores deposits from blocks not higher than the block with the last previously received deposit", %{
    alice: alice,
    bob: bob,
    state_empty: state
  } do
    assert {:ok, _, state} = Core.deposit([%{owner: alice.addr, currency: @eth, amount: 20, blknum: 2}], state)
    assert {:ok, {[], []}, ^state} = Core.deposit([%{owner: bob.addr, currency: @eth, amount: 20, blknum: 1}], state)
  end

  test "extract_initial_state function returns error when passed last deposit as :not_found" do
    assert {:error, :last_deposit_not_found} = Core.extract_initial_state([], 0, :not_found, @interval)
  end

  test "extract_initial_state function returns error when passed top block number as :not_found" do
    assert {:error, :top_block_number_not_found} = Core.extract_initial_state([], :not_found, 0, @interval)
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can't spend nonexistent", %{alice: alice, bob: bob, state_empty: state} do
    state_deposit = state |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})

    state_deposit
    |> Core.exec(create_recovered([{1, 1, 0, alice}, {1, 0, 0, alice}], @eth, [{bob, 7}]), @zero_fees)
    |> fail?(:utxo_not_found)
    |> same?(state_deposit)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend other people's funds", %{alice: alice, bob: bob, state_alice_deposit: state} do
    state
    |> Core.exec(create_recovered([{1, 0, 0, bob}], @eth, [{bob, 8}, {alice, 3}]), @zero_fees)
    |> fail?(:unauthorized_spent)
    |> same?(state)
    |> Core.exec(create_recovered([{1, 0, 0, bob}], @eth, [{alice, 10}]), @zero_fees)
    |> fail?(:unauthorized_spent)
    |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend spent", %{alice: alice, bob: bob, state_alice_deposit: state} do
    transactions = [
      create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}]),
      create_recovered([{0, 0, 0, %{priv: <<>>, addr: nil}}, {1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}])
    ]

    for first <- transactions,
        second <- transactions do
      state |> Core.exec(first, @zero_fees) |> success? |> Core.exec(second, @zero_fees) |> fail?(:utxo_not_found)
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
    |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}]), @zero_fees)
    |> success?
    |> Core.exec(create_recovered([{@blknum1, 0, 0, bob}], @eth, [{carol, 7}]), @zero_fees)
    |> success?
    |> Core.exec(create_recovered([{@blknum1, 0, 1, alice}], @eth, [{carol, 3}]), @zero_fees)
    |> success?
    |> Core.exec(create_recovered([{@blknum1, 1, 0, carol}, {@blknum1, 2, 0, carol}], @eth, [{alice, 10}]), @zero_fees)
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can spend after block is formed", %{alice: alice, bob: bob, state_alice_deposit: state} do
    next_block_height = @blknum2
    {:ok, {_, _, _}, state} = form_block_check(state)

    state
    |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}]), @zero_fees)
    |> success?
    |> Core.exec(create_recovered([{next_block_height, 0, 0, bob}], @eth, [{bob, 7}]), @zero_fees)
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block doesn't unspend", %{alice: alice, bob: bob, state_alice_deposit: state} do
    recovered = create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}])

    {:ok, {_, _, _}, state} =
      state
      |> Core.exec(recovered, @zero_fees)
      |> success?
      |> form_block_check()

    Core.exec(state, recovered, @zero_fees) |> fail?(:utxo_not_found) |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "spending emits event trigger", %{alice: alice, bob: bob, state_alice_deposit: state} do
    recover1 = create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}])
    recover2 = create_recovered([{1000, 0, 0, bob}], @eth, [{alice, 3}])

    assert {:ok, {%Block{hash: block_hash, number: block_number}, triggers, _}, _} =
             state
             |> Core.exec(recover1, @zero_fees)
             |> success?
             |> Core.exec(recover2, @zero_fees)
             |> success?
             |> form_block_check()

    assert triggers == [
             %{tx: recover1, child_blknum: block_number, child_txindex: 0, child_block_hash: block_hash},
             %{tx: recover2, child_blknum: block_number, child_txindex: 1, child_block_hash: block_hash}
           ]
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "every spending emits event triggers", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}]), @zero_fees)
      |> success?
      |> Core.exec(create_recovered([{@blknum1, 0, 0, bob}], @eth, [{alice, 7}]), @zero_fees)
      |> success?

    assert {:ok, {_, [_trigger1, _trigger2], _}, _} = form_block_check(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "only successful spending emits event trigger", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state
    |> Core.exec(create_recovered([{1, 1, 0, alice}], @eth, [{bob, 7}, {alice, 3}]), @zero_fees)
    |> same?(state)

    assert {:ok, {_, [], _}, _} = form_block_check(state)
  end

  @tag fixtures: [:alice, :state_empty]
  test "deposits emit event triggers, they don't leak into next block", %{
    alice: alice,
    state_empty: state
  } do
    assert {:ok, {[trigger], _}, state} = Core.deposit([%{owner: alice, currency: @eth, amount: 4, blknum: 1}], state)

    assert trigger == %{deposit: %{owner: alice, amount: 4}}
    assert {:ok, {_, [], _}, _} = form_block_check(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "empty blocks emit empty event triggers", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}]), @zero_fees)
      |> success?

    assert {:ok, {_, [_trigger], _}, state} = form_block_check(state)

    assert {:ok, {_, [], _}, _} = form_block_check(state)
  end

  @tag fixtures: [:stable_alice, :stable_bob, :state_stable_alice_deposit]
  test "forming block puts all transactions in a block", %{
    stable_alice: alice,
    stable_bob: bob,
    state_stable_alice_deposit: state
  } do
    # odd number of transactions, just in case
    recovered_tx_1 = create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}])
    recovered_tx_2 = create_recovered([{@blknum1, 0, 0, bob}], @eth, [{alice, 2}, {bob, 5}])

    recovered_tx_3 = create_recovered([{@blknum1, 0, 1, alice}], @eth, [{alice, 2}, {bob, 1}])

    state =
      state
      |> Core.exec(recovered_tx_1, @zero_fees)
      |> success?
      |> Core.exec(recovered_tx_2, @zero_fees)
      |> success?
      |> Core.exec(recovered_tx_3, @zero_fees)
      |> success?

    assert {:ok,
            {%Block{
               transactions: [block_tx1, block_tx2, _third_tx],
               hash: block_hash,
               number: @blknum1
             }, _, _}, _} = form_block_check(state)

    # precomputed fixed hash to check compliance with hashing algo
    assert block_hash |> Base.encode16(case: :lower) ==
             "ee44e104950e8784c17495e423493c54026fa554180bbbca057c1176bc4e1ded"

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
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}]), @zero_fees)
      |> success?

    {:ok, {_, _, _}, state} = form_block_check(state)
    expected_block = empty_block(@blknum2)

    assert {:ok, {^expected_block, _, _}, _} = form_block_check(state)
  end

  @tag fixtures: [:state_empty]
  test "no pending transactions at start (no events, empty block, no db updates)", %{state_empty: state} do
    expected_block = empty_block()

    assert {:ok, {^expected_block, [], [{:put, :block, _}, {:put, :child_top_block_number, @blknum1}]}, _state} =
             form_block_check(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "spending produces db updates, that don't leak to next block", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    # persistence tested in-depth elsewhere
    {:ok, {_, _, [_ | _]}, state} =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}]), @zero_fees)
      |> success?
      |> form_block_check()

    assert {:ok, {_, _, [{:put, :block, _}, {:put, :child_top_block_number, @blknum2}]}, _} = form_block_check(state)
  end

  @tag fixtures: [:alice, :state_empty]
  test "depositing produces db updates, that don't leak to next block", %{
    alice: alice,
    state_empty: state
  } do
    # persistence tested in-depth elsewhere
    assert {:ok, {_, [_ | _]}, state} =
             Core.deposit([%{owner: alice.addr, currency: @eth, amount: 10, blknum: 1}], state)

    assert {:ok, {_, _, [{:put, :block, _}, {:put, :child_top_block_number, @blknum1}]}, _} = form_block_check(state)
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "spends utxo validly when exiting", %{alice: alice, state_alice_deposit: state} do
    # persistence tested in-depth elsewhere
    state =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 7}, {alice, 3}]), @zero_fees)
      |> success?

    expected_owner = alice.addr

    utxo_pos_exit_1 = Utxo.position(@blknum1, 0, 0)
    utxo_pos_exit_2 = Utxo.position(@blknum1, 0, 1)
    utxo_pos_exits = [utxo_pos_exit_1, utxo_pos_exit_2]

    assert {:ok,
            {[
               %{exit: %{owner: ^expected_owner, utxo_pos: ^utxo_pos_exit_1}},
               %{exit: %{owner: ^expected_owner, utxo_pos: ^utxo_pos_exit_2}}
             ], [_ | _], {[^utxo_pos_exit_1, ^utxo_pos_exit_2], []}},
            state_after_exit} =
             exit_utxos_response =
             utxo_pos_exits
             |> Core.exit_utxos(state)

    # alternative api of exit_utxos gives the same result and new state
    assert ^exit_utxos_response =
             utxo_pos_exits
             |> Enum.map(&%{utxo_pos: Utxo.Position.encode(&1)})
             |> Core.exit_utxos(state)

    state_after_exit
    |> Core.exec(create_recovered([{@blknum1, 0, 0, alice}], @eth, [{alice, 7}]), @zero_fees)
    |> fail?(:utxo_not_found)
    |> same?(state_after_exit)
    |> Core.exec(create_recovered([{@blknum1, 0, 1, alice}], @eth, [{alice, 3}]), @zero_fees)
    |> fail?(:utxo_not_found)
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "removed utxo after piggyback from available utxo", %{alice: alice, state_alice_deposit: state} do
    # persistence tested in-depth elsewhere
    %Transaction.Recovered{tx_hash: tx_hash, signed_tx: %Transaction.Signed{raw_tx: raw_tx}} =
      tx = create_recovered([{1, 0, 0, alice}], @eth, [{alice, 7}, {alice, 3}])

    state =
      state
      |> Core.exec(tx, @zero_fees)
      |> success?

    expected_owner = alice.addr
    utxo_pos_exits_in_flight = [%{call_data: %{in_flight_tx: Transaction.encode(raw_tx)}}]
    utxo_pos_exits_piggyback = [%{tx_hash: tx_hash, output_index: 4}]
    expected_position = Utxo.position(@blknum1, 0, 0)

    assert {:ok, {[], [], {[], _}}, ^state} = Core.exit_utxos(utxo_pos_exits_in_flight, state)

    assert {:ok,
            {[%{exit: %{owner: ^expected_owner, utxo_pos: ^expected_position}}], [_ | _], {[^expected_position], []}},
            state_after_exit} = Core.exit_utxos(utxo_pos_exits_piggyback, state)

    state_after_exit
    |> Core.exec(create_recovered([{@blknum1, 0, 0, alice}], @eth, [{alice, 7}]), @zero_fees)
    |> fail?(:utxo_not_found)
    |> same?(state_after_exit)
    |> Core.exec(create_recovered([{@blknum1, 0, 1, alice}], @eth, [{alice, 3}]), @zero_fees)
    |> success?
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "removed in-flight inputs from available utxo", %{alice: alice, state_alice_deposit: state} do
    # persistence tested in-depth elsewhere
    state =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 7}, {alice, 3}]), @zero_fees)
      |> success?

    %Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: raw_tx}} =
      create_recovered([{@blknum1, 0, 0, alice}], @eth, [{alice, 3}, {alice, 3}])

    expected_owner = alice.addr
    utxo_pos_exits_in_flight = [%{call_data: %{in_flight_tx: Transaction.encode(raw_tx)}}]
    expected_position = Utxo.position(@blknum1, 0, 0)

    assert {:ok,
            {[%{exit: %{owner: ^expected_owner, utxo_pos: ^expected_position}}], [_ | _], {[^expected_position], _}},
            state_after_exit} = Core.exit_utxos(utxo_pos_exits_in_flight, state)

    state_after_exit
    |> Core.exec(create_recovered([{@blknum1, 0, 0, alice}], @eth, [{alice, 7}]), @zero_fees)
    |> fail?(:utxo_not_found)
    |> same?(state_after_exit)
    |> Core.exec(create_recovered([{@blknum1, 0, 1, alice}], @eth, [{alice, 3}]), @zero_fees)
    |> success?
  end

  @tag fixtures: [:state_empty]
  test "notifies about invalid utxo exiting", %{state_empty: state} do
    utxo_pos_exit_1 = Utxo.position(@blknum1, 0, 0)

    assert {:ok, {[], [], {[], [^utxo_pos_exit_1]}}, ^state} = Core.exit_utxos([utxo_pos_exit_1], state)
  end

  @tag fixtures: [:alice, :state_empty]
  test "tells if utxo exists", %{alice: alice, state_empty: state} do
    assert not Core.utxo_exists?(Utxo.position(1, 0, 0), state)

    state = state |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
    assert Core.utxo_exists?(Utxo.position(1, 0, 0), state)

    state =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}]), @zero_fees)
      |> success?

    assert not Core.utxo_exists?(Utxo.position(1, 0, 0), state)
  end

  @tag fixtures: [:state_empty]
  test "Getting current block height on empty state", %{state_empty: state} do
    assert {@blknum1, _} = Core.get_status(state)
  end

  @tag fixtures: [:state_empty]
  test "Getting current block height with one formed block", %{state_empty: state} do
    {:ok, {_, _, _}, new_state} = state |> form_block_check()
    assert {@blknum2, true} = Core.get_status(new_state)
  end

  @tag fixtures: [:alice, :state_empty]
  test "beginning of block changes when transactions executed and block formed",
       %{alice: alice, state_empty: state} do
    # at empty state it is at the beginning of the next block
    assert {@blknum1, true} = Core.get_status(state)

    # when we execute a tx it isn't at the beginning
    {:ok, _, state} =
      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}]), @zero_fees)

    assert {@blknum1, false} = Core.get_status(state)

    # when a block has been newly formed it is at the beginning
    {:ok, _, state} = state |> form_block_check()

    assert {@blknum2, true} = Core.get_status(state)
  end

  @tag fixtures: [:alice, :state_empty]
  test "Output can have a zero value; can't be used as input though", %{alice: alice, state_empty: state} do
    state
    |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
    |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 8}, {alice, 0}]), @zero_fees)
    |> success?
    |> Core.exec(create_recovered([{1000, 0, 1, alice}], @eth, [{alice, 0}]), @zero_fees)
    |> fail?(:utxo_not_found)
  end

  @tag fixtures: [:alice, :state_empty]
  test "Output with zero value does not change oindex of other outputs", %{alice: alice, state_empty: state} do
    state
    |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
    |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 0}, {alice, 8}]), @zero_fees)
    |> success?
    |> Core.exec(create_recovered([{1000, 0, 1, alice}], @eth, [{alice, 1}]), @zero_fees)
    |> success?
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "Output with zero value will not be written to DB", %{alice: alice, state_alice_deposit: state} do
    state =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 0}]), @zero_fees)
      |> success?

    {:ok, {_, _, db_updates}, _} = form_block_check(state)
    assert [] = Enum.filter(db_updates, &match?({:put, :utxo, _}, &1))
  end

  @tag fixtures: [:alice, :state_empty]
  test "Transaction can have no outputs", %{alice: alice, state_empty: state} do
    state
    |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
    |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, []), @zero_fees)
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "Does not allow executing transactions with input utxos from the future", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    future_deposit_blknum = @blknum1 + 1
    state = do_deposit(state, alice, %{amount: 10, currency: @eth, blknum: future_deposit_blknum})

    # input utxo blknum is greater than state's blknum
    state
    |> Core.exec(create_recovered([{future_deposit_blknum, 0, 0, alice}], @eth, [{bob, 6}, {alice, 4}]), @zero_fees)
    |> fail?(:input_utxo_ahead_of_state)

    state
    |> Core.exec(
      create_recovered([{1, 0, 0, alice}, {future_deposit_blknum, 0, 0, alice}], @eth, [{bob, 6}, {alice, 4}]),
      @zero_fees
    )
    |> fail?(:input_utxo_ahead_of_state)

    # when non-existent input comes with a blknum of the current block fail with :utxo_not_found
    state
    |> Core.exec(create_recovered([{@blknum1, 1, 0, alice}], @eth, [{bob, 6}, {alice, 4}]), @zero_fees)
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

  defp empty_block(number \\ @blknum1) do
    %Block{transactions: [], hash: @empty_block_hash, number: number}
  end

  # used to check the invariants in form_block
  # use this throughout this test module instead of Core.form_block
  defp form_block_check(state) do
    {_, {block, _, db_updates}, _} = result = Core.form_block(@interval, state)

    # check if block returned and sent to db_updates is the same
    assert Enum.member?(db_updates, {:put, :block, block})
    # check if that's the only db_update for block
    is_block_put? = fn {operation, type, _} -> operation == :put && type == :block end
    assert Enum.count(db_updates, is_block_put?) == 1

    result
  end
end
