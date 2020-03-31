# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.State.CoreTest do
  @moduledoc """
  Tests functional behaviors of our high-throughput ledger being `OMG.State.Core`. For test related to state
  persistence of this see `OMG.State.PersistenceTest`
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true
  import OMG.TestHelper

  require Logger
  require OMG.Utxo

  alias OMG.Block
  alias OMG.Eth.Configuration
  alias OMG.Fees
  alias OMG.State.Core
  alias OMG.State.Transaction
  alias OMG.Utxo

  @eth OMG.Eth.zero_address()
  @not_eth <<1::size(160)>>
  @interval OMG.Eth.Configuration.child_block_interval()
  @blknum1 @interval
  @blknum2 @interval * 2

  @empty_block_hash <<246, 9, 190, 253, 254, 144, 102, 254, 20, 231, 67, 179, 98, 62, 174, 135, 143, 188, 70, 128, 5,
                      96, 136, 22, 131, 44, 157, 70, 15, 42, 149, 210>>

  @fee %{@eth => [1], @not_eth => [1]}

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can spend deposits", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
    |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}]), @fee)
    |> success?
    |> Core.exec(create_recovered([{@blknum1, 0, 1, alice}], @eth, [{bob, 2}]), @fee)
    |> success?
  end

  describe "Lazy loaded utxo set" do
    @tag fixtures: [:alice, :bob, :state_alice_deposit]
    test "applies utxos with recent spends to check whether utxo should be fetched from db",
         %{alice: alice, bob: bob, state_alice_deposit: state} do
      # make some utxos
      state =
        state
        |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 5}, {bob, 2}, {alice, 2}]), @fee)
        |> success?()
        |> Core.exec(create_recovered([{1000, 0, 0, alice}], @eth, [{bob, 3}, {alice, 1}]), @fee)
        |> success?()

      deposit_pos = Utxo.position(1, 0, 0)
      assert Core.utxo_processed?(deposit_pos, state) == true

      spend_pos = Utxo.position(1000, 0, 0)
      assert Core.utxo_processed?(spend_pos, state) == true

      known_pos = [Utxo.position(1000, 0, 2), Utxo.position(1000, 1, 1)]
      assert Enum.map(known_pos, &Core.utxo_processed?(&1, state)) == [true, true]

      unknown_pos = [Utxo.position(1000, 2, 0), Utxo.position(1000, 1, 2)]
      assert Enum.map(unknown_pos, &Core.utxo_processed?(&1, state)) == [false, false]
    end

    @tag fixtures: [:alice, :state_empty]
    test "transaction input is missing in state", %{alice: alice, state_empty: state} do
      tx = create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])

      state
      |> Core.with_utxos(%{})
      |> Core.exec(tx, @fee)
      |> fail?(:utxo_not_found)
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "all transaction inputs are merged from db", %{alice: alice, bob: bob, state_empty: state} do
      tx = create_recovered([{1000, 0, 0, alice}, {1000, 1, 0, alice}], @eth, [{bob, 7}, {alice, 2}])

      db_utxos = make_utxos([{1000, 0, 0, alice, @eth, 5}, {1000, 1, 0, alice, @eth, 5}])

      state
      |> Core.with_utxos(db_utxos)
      |> Core.exec(tx, @fee)
      |> success?()
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "transaction utxos are mixed in memory and db", %{alice: alice, bob: bob, state_empty: state} do
      tx = create_recovered([{1000, 0, 0, alice}, {1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 2}])

      db_utxos = make_utxos([{1000, 0, 0, alice, @eth, 8}])

      state
      |> do_deposit(alice, %{amount: 2, currency: @eth, blknum: 1})
      |> Core.with_utxos(db_utxos)
      |> Core.exec(tx, @fee)
      |> success?()
    end

    @tag fixtures: [:alice, :bob, :state_alice_deposit]
    test "spending utxo that resides in memory - double spend impossible",
         %{alice: alice, bob: bob, state_alice_deposit: state} do
      tx = create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 2}])

      state
      |> Core.exec(tx, @fee)
      |> success?()
      |> Core.exec(tx, @fee)
      |> fail?(:utxo_not_found)
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "extending state with same utxos does not change it", %{alice: alice, bob: bob, state_empty: state} do
      db_utxos = make_utxos([{1000, 0, 0, alice, @eth, 8}, {1000, 0, 1, bob, @eth, 2}])
      state = Core.with_utxos(state, db_utxos)

      state
      |> Core.with_utxos(db_utxos)
      |> same?(state)
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "extending state partially", %{alice: alice, bob: bob, state_empty: state} do
      db_utxos1 = make_utxos([{1000, 0, 0, alice, @eth, 6}])
      db_utxos2 = make_utxos([{1000, 5, 0, alice, @eth, 6}])

      tx = create_recovered([{1000, 0, 0, alice}, {1000, 5, 0, alice}], @eth, [{bob, 11}])

      state
      |> Core.with_utxos(db_utxos1)
      |> Core.exec(tx, @fee)
      |> fail?(:utxo_not_found)
      |> Core.with_utxos(db_utxos2)
      |> Core.exec(tx, @fee)
      |> success?()
    end
  end

  describe "Transaction amounts and fees" do
    @tag fixtures: [:alice, :bob, :state_empty]
    test "fees are not needed when given :ignore_fees", %{alice: alice, bob: bob, state_empty: state} do
      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 5}, {alice, 5}]), :ignore_fees)
      |> success?
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "fees can be overpaid when given :ignore_fees", %{alice: alice, bob: bob, state_empty: state} do
      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 1}, {alice, 1}]), :ignore_fees)
      |> success?
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test ":ignore_fees does not allow output amounts > input amounts", %{alice: alice, bob: bob, state_empty: state} do
      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 10}, {alice, 1}]), :ignore_fees)
      |> fail?(:amounts_do_not_add_up)
    end

    @tag fixtures: [:alice, :state_empty]
    test "output currencies must be included in input currencies", %{alice: alice, state_empty: state} do
      state1 =
        state
        |> do_deposit(alice, %{amount: 10, currency: @not_eth, blknum: 1})
        |> Core.exec(create_recovered([{1, 0, 0, alice}], @not_eth, [{alice, 7}, {alice, 2}]), @fee)
        |> success?

      state1
      |> Core.exec(create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 8}]), @fee)
      |> fail?(:amounts_do_not_add_up)

      state1
      |> Core.exec(
        create_recovered([{1000, 0, 0, alice}], [{alice, @eth, 9}, {alice, @not_eth, 3}]),
        @fee
      )
      |> fail?(:amounts_do_not_add_up)

      state1
      |> Core.exec(create_recovered([{1000, 0, 0, alice}], [{alice, @not_eth, 6}]), @fee)
      |> success?
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "amounts from multiple inputs must add up", %{alice: alice, bob: bob, state_empty: state} do
      state = do_deposit(state, alice, %{amount: 10, currency: @eth, blknum: 1})

      # outputs exceed inputs
      state =
        state
        |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 7}, {bob, 4}]), @fee)
        |> fail?(:amounts_do_not_add_up)
        |> same?(state)
        |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 2}, {alice, 7}]), @fee)
        |> success?

      state
      |> Core.exec(
        create_recovered([{@blknum1, 0, 0, bob}, {@blknum1, 0, 1, alice}], @eth, [{alice, 7}, {bob, 2}]),
        @fee
      )
      |> fail?(:fees_not_covered)
      |> same?(state)
      |> Core.exec(
        create_recovered([{@blknum1, 0, 0, bob}, {@blknum1, 0, 1, alice}], @eth, [{alice, 9}, {bob, 2}]),
        @fee
      )
      |> fail?(:amounts_do_not_add_up)
      |> same?(state)
      |> Core.exec(
        create_recovered([{@blknum1, 0, 0, bob}, {@blknum1, 0, 1, alice}], @eth, [{alice, 6}, {bob, 2}]),
        @fee
      )
      |> success?()
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "Inputs exceeds outputs plus fee", %{alice: alice, bob: bob, state_empty: state} do
      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 4}, {alice, 3}]), @fee)
      |> fail?(:overpaying_fees)
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "Inputs sums up exactly to outputs plus fee", %{alice: alice, bob: bob, state_empty: state} do
      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 5}, {alice, 4}]), @fee)
      |> success?
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "Inputs are not sufficient for outputs plus fee", %{alice: alice, bob: bob, state_empty: state} do
      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 4}]), @fee)
      |> fail?(:fees_not_covered)
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "Zero fee is not allowed, transaction is not processed", %{alice: alice, bob: bob, state_empty: state} do
      fee = %{@eth => %{amount: 0}}

      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 3}, {alice, 7}]), fee)
      |> fail?(:fees_not_covered)
    end

    @tag fixtures: [:alice, :state_empty]
    test "Merge transaction is fee free", %{alice: alice, state_empty: state} do
      fees = %{@eth => %{amount: 2}}
      tx = create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], @eth, [{alice, 15}])
      fee = Fees.for_transaction(tx, fees)

      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> do_deposit(alice, %{amount: 5, currency: @eth, blknum: 2})
      |> Core.exec(tx, fee)
      |> success?
    end

    @tag fixtures: [:alice, :state_empty]
    test "Merge transaction is rejected when overpaying", %{alice: alice, state_empty: state} do
      fees = %{@eth => %{amount: 2}}
      tx = create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], @eth, [{alice, 9}])
      fee = Fees.for_transaction(tx, fees)

      state
      |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
      |> do_deposit(alice, %{amount: 5, currency: @eth, blknum: 2})
      |> Core.exec(tx, fee)
      |> fail?(:overpaying_fees)
    end

    @tag fixtures: [:alice, :bob, :state_empty]
    test "respects fees for transactions with mixed currencies", %{
      alice: alice,
      bob: bob,
      state_empty: state
    } do
      fees = %{@eth => [1], @not_eth => [1]}
      not_fee_token = <<2::160>>

      assert not_fee_token not in Map.keys(fees)

      state =
        state
        |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
        |> do_deposit(alice, %{amount: 2, currency: @not_eth, blknum: 2})
        |> do_deposit(alice, %{amount: 1, currency: @not_eth, blknum: 3})
        |> do_deposit(alice, %{amount: 10, currency: not_fee_token, blknum: 4})

      # fee is paid in the same currency as an output
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, @eth, 10}, {bob, @not_eth, 1}]), fees)
      |> success?

      # fee is paid in different currency than outputs
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}, {3, 0, 0, alice}], [{bob, @eth, 9}, {bob, @eth, 1}]), fees)
      |> success?

      # fee is paid from input not transferred by transaction
      state
      |> Core.exec(
        create_recovered([{1, 0, 0, alice}, {4, 0, 0, alice}], [{bob, not_fee_token, 9}, {bob, not_fee_token, 1}]),
        %{@eth => [10]}
      )
      |> success?

      # fee is respected but amounts don't add up
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, @eth, 10}, {bob, @eth, 1}]), fees)
      |> fail?(:amounts_do_not_add_up)
      # fee is not respected
      |> Core.exec(create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, @eth, 10}, {bob, @not_eth, 2}]), fees)
      |> fail?(:fees_not_covered)
      # transaction transferring only not fee currency still is obliged to fee
      |> Core.exec(create_recovered([{4, 0, 0, alice}], not_fee_token, [{bob, 3}, {alice, 7}]), fees)
      |> fail?(:fees_not_covered)
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
      |> Core.exec(create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, @eth, 1}, {bob, @not_eth, 1}]), @fee)
      |> success?
    end
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can spend a batch of deposits", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
    |> do_deposit(bob, %{amount: 20, currency: @eth, blknum: 2})
    |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 9}]), @fee)
    |> success?
    |> Core.exec(create_recovered([{2, 0, 0, bob}], @eth, [{alice, 19}]), @fee)
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can't spend when signature order does not match input order (restrictive spender checks)",
       %{alice: alice, bob: bob, state_empty: state} do
    state
    |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
    |> do_deposit(bob, %{amount: 20, currency: @eth, blknum: 2})
    |> Core.exec(create_recovered([{1, 0, 0, bob}, {2, 0, 0, alice}], @eth, [{bob, 10}]), @fee)
    |> fail?(:unauthorized_spend)
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "deposits can arrive in any order; `OMG.State.Core` doesn't care about this",
       %{alice: alice, bob: bob, state_empty: state} do
    state
    |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 2})
    |> do_deposit(bob, %{amount: 20, currency: @eth, blknum: 1})
    |> Core.exec(create_recovered([{2, 0, 0, alice}], @eth, [{bob, 9}]), @fee)
    |> success?
    |> Core.exec(create_recovered([{1, 0, 0, bob}], @eth, [{alice, 19}]), @fee)
    |> success?
  end

  test "extract_initial_state function returns error when passed top block number as :not_found" do
    assert {:error, :top_block_number_not_found} =
             Core.extract_initial_state(:not_found, @interval, "NO FEE CLAIMER ADDR!")
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can't spend nonexistent", %{alice: alice, bob: bob, state_empty: state} do
    state_deposit = state |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})

    state_deposit
    |> Core.exec(create_recovered([{1, 1, 0, alice}, {1, 0, 0, alice}], @eth, [{bob, 7}]), @fee)
    |> fail?(:utxo_not_found)
    |> same?(state_deposit)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend other people's funds", %{alice: alice, bob: bob, state_alice_deposit: state} do
    state
    |> Core.exec(create_recovered([{1, 0, 0, bob}], @eth, [{bob, 8}, {alice, 3}]), @fee)
    |> fail?(:unauthorized_spend)
    |> same?(state)
    |> Core.exec(create_recovered([{1, 0, 0, bob}], @eth, [{alice, 10}]), @fee)
    |> fail?(:unauthorized_spend)
    |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "all inputs must be authorized to be spent", %{alice: alice, bob: bob, state_alice_deposit: state} do
    state =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}]), @fee)
      |> success?()

    state
    |> Core.exec(create_recovered([{@blknum1, 0, 0, bob}, {@blknum1, 0, 1, bob}], @eth, [{alice, 1}]), @fee)
    |> fail?(:unauthorized_spend)
    |> same?(state)
    |> Core.exec(create_recovered([{@blknum1, 0, 0, alice}, {@blknum1, 0, 1, alice}], @eth, [{alice, 1}]), @fee)
    |> fail?(:unauthorized_spend)
    |> same?(state)

    state
    |> Core.exec(create_recovered([{@blknum1, 0, 0, bob}, {@blknum1, 0, 1, alice}], @eth, [{alice, 8}]), @fee)
    |> success?()
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend spent", %{alice: alice, bob: bob, state_alice_deposit: state} do
    transactions = [
      create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 2}]),
      create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}])
    ]

    for first <- transactions,
        second <- transactions do
      state
      |> Core.exec(first, @fee)
      |> success?
      |> Core.exec(second, @fee)
      |> fail?(:utxo_not_found)
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
    |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}]), @fee)
    |> success?
    |> Core.exec(create_recovered([{@blknum1, 0, 0, bob}], @eth, [{carol, 5}]), @fee)
    |> success?
    |> Core.exec(create_recovered([{@blknum1, 0, 1, alice}], @eth, [{carol, 2}]), @fee)
    |> success?
    |> Core.exec(create_recovered([{@blknum1, 1, 0, carol}, {@blknum1, 2, 0, carol}], @eth, [{alice, 6}]), @fee)
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can spend after block is formed", %{alice: alice, bob: bob, state_alice_deposit: state} do
    next_block_height = @blknum2
    {:ok, {_, _}, state} = form_block_check(state)

    state
    |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 2}]), @fee)
    |> success?
    |> Core.exec(create_recovered([{next_block_height, 0, 0, bob}], @eth, [{bob, 6}]), @fee)
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block doesn't unspend", %{alice: alice, bob: bob, state_alice_deposit: state} do
    recovered = create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 2}])

    {:ok, {_, _}, state} =
      state
      |> Core.exec(recovered, @fee)
      |> success?
      |> form_block_check()

    Core.exec(state, recovered, @fee) |> fail?(:utxo_not_found) |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't double spend chained txs", %{alice: alice, bob: bob, state_alice_deposit: state} do
    recovered = create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 2}])
    recovered2 = create_recovered([{1000, 0, 0, bob}], @eth, [{bob, 6}])

    state
    |> Core.exec(recovered, @fee)
    |> success?
    |> Core.exec(recovered2, @fee)
    |> success?
    |> Core.exec(recovered2, @fee)
    |> fail?(:utxo_not_found)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend own output", %{bob: bob, state_alice_deposit: state} do
    # The transaction here is designed so that it would spend its own output. Sanity checking first
    {1000, true} = Core.get_status(state)
    recovered2 = create_recovered([{1000, 0, 0, bob}], @eth, [{bob, 6}])

    state
    |> Core.exec(recovered2, @fee)
    |> fail?(:utxo_not_found)
  end

  @tag fixtures: [:stable_alice, :stable_bob, :state_stable_alice_deposit]
  test "forming block puts all transactions in a block", %{
    stable_alice: alice,
    stable_bob: bob,
    state_stable_alice_deposit: state
  } do
    # odd number of transactions, just in case
    recovered_tx_1 = create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}])
    recovered_tx_2 = create_recovered([{@blknum1, 0, 0, bob}], @eth, [{alice, 3}, {bob, 2}])
    recovered_tx_3 = create_recovered([{@blknum1, 0, 1, alice}], @eth, [{alice, 1}, {bob, 1}])

    state =
      state
      |> Core.exec(recovered_tx_1, @fee)
      |> success?
      |> Core.exec(recovered_tx_2, @fee)
      |> success?
      |> Core.exec(recovered_tx_3, @fee)
      |> success?

    assert {:ok,
            {%Block{
               transactions: [block_tx1, block_tx2, _third_tx],
               hash: block_hash,
               number: @blknum1
             }, _}, _} = form_block_check(state)

    # precomputed fixed hash to check compliance with hashing algo
    assert <<240, 92, 32, 48, 163, 193, 58, 124, 248, 71>> <> _ = block_hash

    # Check that contents of the block can be recovered again to original txs
    assert {:ok, ^recovered_tx_1} = Transaction.Recovered.recover_from(block_tx1)
    assert {:ok, ^recovered_tx_2} = Transaction.Recovered.recover_from(block_tx2)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block empty block after a non-empty block", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 2}]), @fee)
      |> success?

    {:ok, {_, _}, state} = form_block_check(state)
    expected_block = empty_block(@blknum2)

    assert {:ok, {^expected_block, _}, _} = form_block_check(state)
  end

  @tag fixtures: [:state_empty]
  test "no pending transactions at start (empty block, no db updates)", %{state_empty: state} do
    expected_block = empty_block()

    assert {:ok, {^expected_block, [{:put, :block, _}, {:put, :child_top_block_number, @blknum1}]}, _state} =
             form_block_check(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "spending produces db updates, that don't leak to next block", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    # persistence tested in-depth elsewhere
    {:ok, {_, [_ | _]}, state} =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 2}]), @fee)
      |> success?
      |> form_block_check()

    assert {:ok, {_, [{:put, :block, _}, {:put, :child_top_block_number, @blknum2}]}, _} = form_block_check(state)
  end

  @tag fixtures: [:alice, :state_empty]
  test "depositing produces db updates, that don't leak to next block", %{
    alice: alice,
    state_empty: state
  } do
    # persistence tested in-depth elsewhere
    assert {:ok, [_ | _], state} = Core.deposit([%{owner: alice.addr, currency: @eth, amount: 10, blknum: 1}], state)

    assert {:ok, {_, [{:put, :block, _}, {:put, :child_top_block_number, @blknum1}]}, _} = form_block_check(state)
  end

  @tag fixtures: [:alice, :state_alice_deposit, :state_empty]
  test "given exit infos in various forms translates to utxo positions",
       %{alice: alice, state_alice_deposit: state, state_empty: state_empty} do
    # this test checks whether all ways of calling `get_exiting_utxo_positions/2` translates
    # to given exiting utxo positions
    utxo_pos_exits = [Utxo.position(@blknum1, 0, 0), Utxo.position(@blknum1, 0, 1)]

    assert utxo_pos_exits ==
             utxo_pos_exits
             |> Enum.map(&%{call_data: %{utxo_pos: Utxo.Position.encode(&1)}})
             |> Core.extract_exiting_utxo_positions(state_empty)

    assert utxo_pos_exits ==
             utxo_pos_exits
             |> Enum.map(&%{utxo_pos: Utxo.Position.encode(&1)})
             |> Core.extract_exiting_utxo_positions(state_empty)

    assert utxo_pos_exits ==
             utxo_pos_exits
             |> Enum.map(&Utxo.Position.encode/1)
             |> Core.extract_exiting_utxo_positions(state_empty)

    %Transaction.Recovered{tx_hash: tx_hash} = tx = create_recovered([{1, 0, 0, alice}], @eth, [{alice, 7}, {alice, 2}])

    piggybacks = [
      %{tx_hash: tx_hash, output_index: 0, omg_data: %{piggyback_type: :output}},
      %{tx_hash: tx_hash, output_index: 1, omg_data: %{piggyback_type: :output}}
    ]

    state =
      state
      |> Core.exec(tx, @fee)
      |> success?

    assert utxo_pos_exits == Core.extract_exiting_utxo_positions(piggybacks, state)
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "spends utxo validly when exiting", %{alice: alice, state_alice_deposit: state} do
    # persistence tested in-depth elsewhere
    state =
      state
      |> Core.exec(
        create_recovered([{1, 0, 0, alice}], @eth, [{alice, 6}, {alice, 3}]),
        @fee
      )
      |> success?

    utxo_pos_exit_1 = Utxo.position(@blknum1, 0, 0)
    utxo_pos_exit_2 = Utxo.position(@blknum1, 0, 1)
    utxo_pos_exits = [utxo_pos_exit_1, utxo_pos_exit_2]

    assert {:ok, {[_ | _], {[^utxo_pos_exit_1, ^utxo_pos_exit_2], []}}, state_after_exit} =
             Core.exit_utxos(utxo_pos_exits, state)

    state_after_exit
    |> Core.exec(create_recovered([{@blknum1, 0, 0, alice}], @eth, [{alice, 6}]), @fee)
    |> fail?(:utxo_not_found)
    |> same?(state_after_exit)
    |> Core.exec(create_recovered([{@blknum1, 0, 1, alice}], @eth, [{alice, 2}]), @fee)
    |> fail?(:utxo_not_found)
  end

  @tag fixtures: [:alice, :state_empty]
  test "spends utxo from db when exiting", %{alice: alice, state_empty: state} do
    db_utxos = make_utxos([{@blknum1, 0, 0, alice, @eth, 6}, {@blknum1, 0, 1, alice, @eth, 3}])
    extended_state = Core.with_utxos(state, db_utxos)

    utxo_pos_exit_1 = Utxo.position(@blknum1, 0, 0)
    utxo_pos_exit_2 = Utxo.position(@blknum1, 0, 1)
    utxo_pos_exits = [utxo_pos_exit_1, utxo_pos_exit_2]

    assert {:ok, {[_ | _], {[^utxo_pos_exit_1, ^utxo_pos_exit_2], []}}, state_after_exit} =
             Core.exit_utxos(utxo_pos_exits, extended_state)

    state_after_exit
    |> Core.exec(create_recovered([{@blknum1, 0, 0, alice}], @eth, [{alice, 6}]), @fee)
    |> fail?(:utxo_not_found)
    |> Core.exec(create_recovered([{@blknum1, 0, 1, alice}], @eth, [{alice, 2}]), @fee)
    |> fail?(:utxo_not_found)
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "removed utxo after piggyback from available utxo", %{alice: alice, state_alice_deposit: state} do
    # persistence tested in-depth elsewhere
    tx = create_recovered([{1, 0, 0, alice}], @eth, [{alice, 7}, {alice, 2}])

    state = state |> Core.exec(tx, @fee) |> success?

    utxo_pos_exits_in_flight = [%{call_data: %{in_flight_tx: Transaction.raw_txbytes(tx)}}]

    utxo_pos_exits_piggyback = [
      %{tx_hash: Transaction.raw_txhash(tx), output_index: 0, omg_data: %{piggyback_type: :output}}
    ]

    expected_position = Utxo.position(@blknum1, 0, 0)

    assert {:ok, {[], {[], _}}, ^state} =
             utxo_pos_exits_in_flight
             |> Core.extract_exiting_utxo_positions(state)
             |> Core.exit_utxos(state)

    assert {:ok, {[_ | _], {[^expected_position], []}}, state_after_exit} =
             utxo_pos_exits_piggyback
             |> Core.extract_exiting_utxo_positions(state)
             |> Core.exit_utxos(state)

    state_after_exit
    |> Core.exec(create_recovered([{@blknum1, 0, 0, alice}], @eth, [{alice, 6}]), @fee)
    |> fail?(:utxo_not_found)
    |> same?(state_after_exit)
    |> Core.exec(create_recovered([{@blknum1, 0, 1, alice}], @eth, [{alice, 1}]), @fee)
    |> success?
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "removed in-flight inputs from available utxo", %{alice: alice, state_alice_deposit: state} do
    # persistence tested in-depth elsewhere
    state =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 6}, {alice, 3}]), @fee)
      |> success?

    tx = create_recovered([{@blknum1, 0, 0, alice}], @eth, [{alice, 2}, {alice, 3}])

    utxo_pos_exits_in_flight = [%{call_data: %{in_flight_tx: Transaction.raw_txbytes(tx)}}]
    expected_position = Utxo.position(@blknum1, 0, 0)

    exiting_utxos = Core.extract_exiting_utxo_positions(utxo_pos_exits_in_flight, state)

    assert {:ok, {[_ | _], {[^expected_position], _}}, state_after_exit} = Core.exit_utxos(exiting_utxos, state)

    state_after_exit
    |> Core.exec(create_recovered([{@blknum1, 0, 0, alice}], @eth, [{alice, 5}]), @fee)
    |> fail?(:utxo_not_found)
    |> same?(state_after_exit)
    |> Core.exec(create_recovered([{@blknum1, 0, 1, alice}], @eth, [{alice, 2}]), @fee)
    |> success?
  end

  @tag fixtures: [:state_empty]
  test "notifies about invalid utxo exiting", %{state_empty: state} do
    utxo_pos_exit_1 = Utxo.position(@blknum1, 0, 0)

    assert {:ok, {[], {[], [^utxo_pos_exit_1]}}, ^state} = Core.exit_utxos([utxo_pos_exit_1], state)
  end

  @tag fixtures: [:state_alice_deposit]
  test "ignores a piggyback of a non-included tx's outout", %{state_alice_deposit: state} do
    piggyback_event = %{tx_hash: 1, output_index: 0, omg_data: %{piggyback_type: :output}}

    assert {:ok, {[], {[], []}}, ^state} =
             [piggyback_event]
             |> Core.extract_exiting_utxo_positions(state)
             |> Core.exit_utxos(state)
  end

  @tag fixtures: [:state_alice_deposit]
  test "ignores on exiting, when input piggybacks are detected", %{state_alice_deposit: state} do
    piggyback_event = %{tx_hash: 1, output_index: 0, omg_data: %{piggyback_type: :input}}

    assert {:ok, {[], {[], []}}, ^state} =
             [piggyback_event]
             |> Core.extract_exiting_utxo_positions(state)
             |> Core.exit_utxos(state)
  end

  @tag fixtures: [:alice, :state_empty]
  test "tells if utxo exists", %{alice: alice, state_empty: state} do
    assert not Core.utxo_exists?(Utxo.position(1, 0, 0), state)

    state = state |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
    assert Core.utxo_exists?(Utxo.position(1, 0, 0), state)

    state =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 9}]), @fee)
      |> success?

    assert not Core.utxo_exists?(Utxo.position(1, 0, 0), state)
  end

  @tag fixtures: [:alice, :state_empty]
  test "tells if utxo exists in db-extended state", %{alice: alice, state_empty: state} do
    state = Core.with_utxos(state, make_utxos([{1, 0, 0, alice, @eth, 10}]))
    assert Core.utxo_exists?(Utxo.position(1, 0, 0), state)

    state =
      state
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 9}]), @fee)
      |> success?

    assert not Core.utxo_exists?(Utxo.position(1, 0, 0), state)
  end

  @tag fixtures: [:state_empty]
  test "Getting current block height on empty state", %{state_empty: state} do
    assert {@blknum1, _} = Core.get_status(state)
  end

  @tag fixtures: [:state_empty]
  test "Getting current block height with one formed block", %{state_empty: state} do
    {:ok, {_, _}, new_state} = form_block_check(state)
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
      |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 9}]), @fee)

    assert {@blknum1, false} = Core.get_status(state)

    # when a block has been newly formed it is at the beginning
    {:ok, _, state} = form_block_check(state)

    assert {@blknum2, true} = Core.get_status(state)
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
    |> Core.exec(create_recovered([{future_deposit_blknum, 0, 0, alice}], @eth, [{bob, 5}, {alice, 4}]), @fee)
    |> fail?(:input_utxo_ahead_of_state)

    state
    |> Core.exec(
      create_recovered([{1, 0, 0, alice}, {future_deposit_blknum, 0, 0, alice}], @eth, [{bob, 5}, {alice, 4}]),
      @fee
    )
    |> fail?(:input_utxo_ahead_of_state)

    # when non-existent input comes with a blknum of the current block fail with :utxo_not_found
    state
    |> Core.exec(create_recovered([{@blknum1, 1, 0, alice}], @eth, [{bob, 5}, {alice, 4}]), @fee)
    |> fail?(:utxo_not_found)
  end

  @tag fixtures: [:alice]
  test "no utxos that belong to address within the empty query result", %{alice: %{addr: alice}} do
    assert [] == Core.standard_exitable_utxos([], alice)
  end

  @tag fixtures: [:alice, :bob, :carol]
  test "getting user utxos from utxos_query_result",
       %{alice: alice, bob: bob, carol: carol} do
    output_type = OMG.WireFormatTypes.output_type_for(:output_payment_v1)

    utxos_query_result = [
      {{1000, 0, 0},
       %{output: %{amount: 1, currency: @eth, owner: alice.addr, output_type: output_type}, creating_txhash: "nil"}},
      {{2000, 1, 1},
       %{output: %{amount: 2, currency: @eth, owner: bob.addr, output_type: output_type}, creating_txhash: "nil"}},
      {{1000, 2, 0},
       %{
         output: %{amount: 3, currency: @not_eth, owner: alice.addr, output_type: output_type},
         creating_txhash: "nil"
       }},
      {{1000, 3, 1},
       %{output: %{amount: 4, currency: @eth, owner: alice.addr, output_type: output_type}, creating_txhash: "nil"}},
      {{1000, 4, 0},
       %{output: %{amount: 5, currency: @eth, owner: bob.addr, output_type: output_type}, creating_txhash: "nil"}}
    ]

    assert [] == Core.standard_exitable_utxos(utxos_query_result, carol.addr)

    assert MapSet.equal?(
             MapSet.new([
               %{blknum: 1000, txindex: 0, oindex: 0, otype: output_type, owner: alice.addr, currency: @eth, amount: 1},
               %{
                 blknum: 1000,
                 txindex: 2,
                 oindex: 0,
                 otype: output_type,
                 owner: alice.addr,
                 currency: @not_eth,
                 amount: 3
               },
               %{blknum: 1000, txindex: 3, oindex: 1, otype: output_type, owner: alice.addr, currency: @eth, amount: 4}
             ]),
             MapSet.new(Core.standard_exitable_utxos(utxos_query_result, alice.addr))
           )

    assert Map.equal?(
             MapSet.new([
               %{blknum: 1000, txindex: 4, oindex: 0, otype: output_type, owner: bob.addr, currency: @eth, amount: 5},
               %{blknum: 2000, txindex: 1, oindex: 1, otype: output_type, owner: bob.addr, currency: @eth, amount: 2}
             ]),
             MapSet.new(Core.standard_exitable_utxos(utxos_query_result, bob.addr))
           )
  end

  describe "Automatic fees claiming" do
    setup do
      fee_claimer = OMG.TestHelper.generate_entity()

      child_block_interval = Configuration.child_block_interval()
      {:ok, state_empty} = Core.extract_initial_state(0, child_block_interval, fee_claimer.addr)

      alice = OMG.TestHelper.generate_entity()
      fees = %{@eth => [2]}

      state =
        state_empty
        |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
        |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 8}]), fees)
        |> success?()

      {:ok, [state: state, alice: alice, fees: fees, fee_claimer: fee_claimer, state_empty: state_empty]}
    end

    test "should append fee txs in block", %{state: state} do
      state = Core.claim_fees(state)
      {:ok, {block, _dbupdates}, _state} = form_block_check(state)

      assert [payment_txbytes, fee_txbytes] = block.transactions

      assert %Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: %Transaction.Payment{}}} =
               Transaction.Recovered.recover_from!(payment_txbytes)

      assert %Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: %Transaction.Fee{}}} =
               Transaction.Recovered.recover_from!(fee_txbytes)
    end

    test "fee txs are appended even when fees aren't required", %{state: state} do
      state = Core.claim_fees(state)
      {:ok, {block, _dbupdates}, _state} = form_block_check(state)

      assert 2 = length(block.transactions)
    end

    test "should create utxos from claimed fee", %{alice: alice, state: state, fee_claimer: fee_claimer} do
      state = Core.claim_fees(state)
      {:ok, _, state} = form_block_check(state)

      state
      |> Core.exec(create_recovered([{1000, 1, 0, fee_claimer}], @eth, [{alice, 2}]), :no_fees_required)
      |> success?()
    end

    test "fee txs cannot be intermixed with payments", %{alice: alice, state: state, fees: fees} do
      fee_tx = create_recovered_fee_tx(1000, state.fee_claimer_address, @eth, 2)

      state
      # fees from 1st tx are available to claim
      |> Core.exec(fee_tx, fees)
      |> success?()
      # at this point no other payment can be processed
      |> Core.exec(create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 5}]), fees)
      |> fail?(:payments_rejected_during_fee_claiming)
    end

    test "cannot claim the same token twice", %{state: state, fees: fees} do
      fee_tx = create_recovered_fee_tx(1000, state.fee_claimer_address, @eth, 2)

      state
      # fees from 1st tx are available to claim
      |> Core.exec(fee_tx, fees)
      |> success?()
      # at this point no other payment can be processed
      |> Core.exec(fee_tx, fees)
      |> fail?(:surplus_in_token_not_collected)
    end

    test "cannot claim more than collected", %{state: state, fees: fees} do
      paid_fee = 2

      fee_tx = create_recovered_fee_tx(1000, state.fee_claimer_address, @eth, paid_fee + 1)

      state
      |> Core.exec(fee_tx, fees)
      |> fail?(:claimed_and_collected_amounts_mismatch)
    end

    test "cannot claim less than collected", %{state: state, fees: fees} do
      paid_fee = 2

      fee_tx = create_recovered_fee_tx(1000, state.fee_claimer_address, @eth, paid_fee - 1)

      state
      |> Core.exec(fee_tx, fees)
      |> fail?(:claimed_and_collected_amounts_mismatch)
    end

    test "no fees can be claimed after block is formed", %{state: state, fees: fees} do
      fee_tx = create_recovered_fee_tx(1000, state.fee_claimer_address, @eth, 2)

      # now it's possible to claim Eth fee (note: no state modification)
      state
      |> Core.exec(fee_tx, fees)
      |> success?()

      # block is formed without claiming fees
      {:ok, {_block, _dbupdates}, new_state} = form_block_check(state)

      # it's no longer possible to claim fees
      new_state
      |> Core.exec(fee_tx, fees)
      |> fail?(:surplus_in_token_not_collected)
    end

    test "fee is paid in one token only, many surpluses prohibited", %{alice: alice, state: state, fees: fees} do
      state
      |> do_deposit(alice, %{amount: 100, currency: @not_eth, blknum: 2})
      |> Core.exec(
        create_recovered([{1000, 0, 0, alice}, {2, 0, 0, alice}], [{alice, @eth, 5}, {alice, @not_eth, 90}]),
        fees
      )
      |> fail?(:multiple_potential_currency_fees)
    end

    test "zero surplus is not collectable", %{alice: alice, state: state, fees: fees} do
      state =
        state
        |> do_deposit(alice, %{amount: 100, currency: @not_eth, blknum: 2})
        |> Core.exec(
          create_recovered([{1000, 0, 0, alice}, {2, 0, 0, alice}], [{alice, @eth, 6}, {alice, @not_eth, 100}]),
          fees
        )
        |> success?()

      # not_eth currency is transferred in full - no surplus exists
      state
      |> Core.exec(create_recovered_fee_tx(1000, state.fee_claimer_address, @not_eth, 1), fees)
      |> fail?(:surplus_in_token_not_collected)
    end

    test "multi-input/output transaction - pay fees from no-zero index",
         %{alice: alice, state_empty: state, fees: fees} do
      not_eth_1 = <<123::160>>
      not_eth_2 = <<234::160>>

      state =
        state
        |> do_deposit(alice, %{amount: 10, currency: @eth, blknum: 1})
        |> do_deposit(alice, %{amount: 10, currency: @not_eth, blknum: 2})
        |> do_deposit(alice, %{amount: 10, currency: not_eth_1, blknum: 3})
        |> do_deposit(alice, %{amount: 10, currency: not_eth_2, blknum: 4})
        |> Core.exec(
          create_recovered(
            [{3, 0, 0, alice}, {2, 0, 0, alice}, {1, 0, 0, alice}, {4, 0, 0, alice}],
            [{alice, @not_eth, 10}, {alice, @eth, 8}, {alice, not_eth_2, 10}, {alice, not_eth_1, 10}]
          ),
          fees
        )
        |> success?()

      fee_tx = create_recovered_fee_tx(1000, state.fee_claimer_address, @eth, 2)

      assert %Core{pending_txs: [^fee_tx | _]} = Core.claim_fees(state)
    end

    test "surpluses adding up for same-token-fees paid in a block", %{alice: alice, state: state, fees: fees} do
      state =
        state
        |> Core.exec(create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 6}]), fees)
        |> success?()

      # we can claim sum of the surpluses from 2 txs (one in setup & one above)
      collected = 2 + 2

      state
      |> Core.exec(create_recovered_fee_tx(1000, state.fee_claimer_address, @eth, collected), fees)
      |> success?()
    end

    # this test takes ~26 seconds on my machine
    @tag slow: true
    test "long running full block test", %{alice: alice, state_empty: state, fees: fees} do
      Logger.warn("slow test is running, use --exclude slow to skip")

      maximum_block_size = 65_536
      maximum_inputs_size = 4
      eth_fee_rate = Enum.at(fees[@eth], 0)
      amount_for_fees = (1 + eth_fee_rate) * maximum_block_size
      available_after_1st_tx = amount_for_fees - eth_fee_rate

      # First tx is applied just to make below transactions generation easier
      state =
        state
        |> do_deposit(alice, %{amount: amount_for_fees, currency: @eth, blknum: 1})
        |> Core.exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, available_after_1st_tx}]), fees)
        |> success?()

      # we just send 1 payment and this reserves 1 spot for fee
      already_reserved = 2

      # available space is block_size
      ntx_to_apply = maximum_block_size - (1 + maximum_inputs_size + already_reserved)

      {state, _} =
        Enum.reduce(0..ntx_to_apply, {state, available_after_1st_tx}, fn index, {curr_state, amount} ->
          new_amount = amount - eth_fee_rate

          new_state =
            curr_state
            |> Core.exec(create_recovered([{1000, index, 0, alice}], @eth, [{alice, new_amount}]), fees)
            |> success?()

          {new_state, new_amount}
        end)

      state
      # NOTE: I don't care about existing utxo actual position or available amount because block size is checked first
      |> Core.exec(create_recovered([{2, 0, 0, alice}], @eth, [{alice, 1_000_000}]), fees)
      |> fail?(:too_many_transactions_in_block)
    end
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
    {_, {block, db_updates}, _} = result = Core.form_block(state)

    # check if block returned and sent to db_updates is the same
    assert Enum.member?(db_updates, {:put, :block, Block.to_db_value(block)})
    # check if that's the only db_update for block
    is_block_put? = fn {operation, type, _} -> operation == :put && type == :block end
    assert Enum.count(db_updates, is_block_put?) == 1

    result
  end

  defp make_utxos(utxos) when is_list(utxos), do: Enum.into(utxos, %{}, &to_utxo_kv/1)

  defp to_utxo_kv({blknum, txindex, oindex, owner, currency, amount}),
    do: {
      Utxo.position(blknum, txindex, oindex),
      %Utxo{output: %OMG.Output{amount: amount, currency: currency, owner: owner.addr}}
    }
end
