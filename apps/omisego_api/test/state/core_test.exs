defmodule OmiseGO.API.State.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.Transaction

  @block_interval 1000
  @empty_block_hash <<39, 51, 229, 15, 82, 110, 194, 250, 25, 162, 43, 49, 232, 237, 80, 242, 60,
                      209, 253, 249, 76, 145, 84, 237, 58, 118, 9, 162, 241, 255, 152, 31>>

  def do_deposit(state, owner, %{amount: amount, block_height: block_height}) do
    {_, _, new_state} =
      Core.deposit([%{owner: owner.addr, amount: amount, block_height: block_height}], state)

    new_state
  end

  def create_recover(input, output, fee) do
    splenders =
      input
      |> Enum.with_index(1)
      |> Enum.map(fn {%{owner: owner}, index} ->
        {String.to_existing_atom("spender#{index}"), owner.addr}
      end)
      |> Enum.into(%{})

    raw_tx =
      Transaction.new(
        input |> Enum.map(&Map.delete(&1, :owner)),
        output |> Enum.map(&%{&1 | newowner: &1.newowner.addr}),
        fee
      )

    [sig1, sig2 | _] =
      input |> Enum.map(fn %{owner: owner} -> owner.priv end) |> Enum.concat([<<>>, <<>>])

    signed_tx_hash = raw_tx |> Transaction.sign(sig1, sig2) |> Transaction.Signed.hash()

    struct(
      Transaction.Recovered,
      Map.merge(%{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash}, splenders)
    )
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can spend deposits", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> do_deposit(alice, %{amount: 10, block_height: 1})
    |> (&Core.exec(
          create_recover(
            [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
            [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
            0
          ),
          &1
        )).()
    |> success?
    |> (&Core.exec(
          create_recover(
            [%{blknum: @block_interval, txindex: 0, oindex: 1, owner: alice}],
            [%{newowner: bob, amount: 3}],
            0
          ),
          &1
        )).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can spend a batch of deposits", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> do_deposit(alice, %{amount: 10, block_height: 1})
    |> do_deposit(bob, %{amount: 20, block_height: 2})
    |> (&Core.exec(
          create_recover(
            [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
            [%{newowner: bob, amount: 10}],
            0
          ),
          &1
        )).()
    |> success?
    |> (&Core.exec(
          create_recover(
            [%{blknum: 2, txindex: 0, oindex: 0, owner: bob}],
            [%{newowner: alice, amount: 20}],
            0
          ),
          &1
        )).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "ignores deposits from blocks not higher than the block with the last previously received deposit",
       %{alice: alice, bob: bob, state_empty: state} do
    deposits = [
      %{owner: alice.addr, amount: 20, block_height: 2}
    ]

    assert {_, [_, {:put, :last_deposit_block_height, 2}], state} = Core.deposit(deposits, state)

    assert {[], [], ^state} =
             Core.deposit([%{owner: bob.addr, amount: 20, block_height: 1}], state)
  end

  @tag fixtures: [:bob]
  test "ignores deposits from blocks not higher than the deposit height read from db", %{bob: bob} do
    state = Core.extract_initial_state(%{}, 0, 1, @block_interval)

    assert {[], [], ^state} =
             Core.deposit([%{owner: bob.addr, amount: 20, block_height: 1}], state)
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can't spend nonexistent", %{alice: alice, bob: bob, state_empty: state} do
    state_deposit = state |> do_deposit(alice, %{amount: 10, block_height: 1})

    state_deposit
    |> (&Core.exec(
          create_recover(
            [%{blknum: 1, txindex: 1, oindex: 0, owner: alice}],
            [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
            0
          ),
          &1
        )).()
    |> fail?(:utxo_not_found)
    |> same?(state_deposit)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit, :state_empty]
  test "amounts must add up", %{alice: alice, bob: bob, state_empty: state} do
    state = do_deposit(state, alice, %{amount: 10, block_height: 1})

    state =
      state
      |> (&Core.exec(
            create_recover(
              [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
              [%{newowner: alice, amount: 8}, %{newowner: bob, amount: 3}],
              0
            ),
            &1
          )).()
      |> fail?(:amounts_dont_add_up)
      |> same?(state)
      |> (&Core.exec(
            create_recover(
              [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
              [%{newowner: bob, amount: 8}, %{newowner: alice, amount: 2}],
              1
            ),
            &1
          )).()
      |> fail?(:amounts_dont_add_up)
      |> same?(state)
      |> (&Core.exec(
            %{
              create_recover(
                [
                  %{blknum: 0, txindex: 0, oindex: 0, owner: alice},
                  %{blknum: 1, txindex: 0, oindex: 0, owner: bob}
                ],
                [%{newowner: bob, amount: 8}, %{newowner: alice, amount: 3}],
                0
              )
              | spender1: nil,
                spender2: alice.addr
            },
            &1
          )).()
      |> fail?(:amounts_dont_add_up)
      |> same?(state)
      |> (&Core.exec(
            create_recover(
              [
                %{blknum: 1, txindex: 0, oindex: 0, owner: alice}
              ],
              [%{newowner: bob, amount: 2}, %{newowner: alice, amount: 8}],
              0
            ),
            &1
          )).()
      |> success?

    state
    |> (&Core.exec(
          %{
            create_recover(
              [
                %{blknum: @block_interval, txindex: 0, oindex: 0, owner: alice},
                %{blknum: @block_interval, txindex: 0, oindex: 1, owner: bob}
              ],
              [%{newowner: alice, amount: 8}, %{newowner: bob, amount: 3}],
              0
            )
            | spender1: bob.addr,
              spender2: alice.addr
          },
          &1
        )).()
    |> fail?(:amounts_dont_add_up)
    |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend other people's funds", %{alice: alice, bob: bob, state_alice_deposit: state} do
    state
    |> (&Core.exec(
          create_recover(
            [%{blknum: 1, txindex: 0, oindex: 0, owner: bob}],
            [%{newowner: bob, amount: 8}, %{newowner: alice, amount: 3}],
            0
          ),
          &1
        )).()
    |> fail?(:incorrect_spender)
    |> same?(state)
    |> (&Core.exec(
          create_recover(
            [%{blknum: 1, txindex: 0, oindex: 0, owner: bob}],
            [%{newowner: bob, amount: 8}, %{newowner: alice, amount: 3}],
            0
          ),
          &1
        )).()
    |> fail?(:incorrect_spender)
    |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend spent", %{alice: alice, bob: bob, state_alice_deposit: state} do
    # FIXME dry - we need many cases since attempt to spend spend might be done in 4 different ways
    bad_transaction =
      create_recover(
        [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
        [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
        0
      )

    bad_transaction2 =
      create_recover(
        [
          %{blknum: 0, txindex: 0, oindex: 0, owner: %{priv: <<>>, addr: nil}},
          %{blknum: 1, txindex: 0, oindex: 0, owner: alice}
        ],
        [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
        0
      )

    state1 =
      state
      |> (&Core.exec(
            create_recover(
              [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
              [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
              0
            ),
            &1
          )).()
      |> success?

    state2 =
      state
      |> (&Core.exec(
            create_recover(
              [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
              [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
              0
            ),
            &1
          )).()
      |> success?

    [state1, state2]
    |> Enum.map(fn state ->
      state
      |> (&Core.exec(bad_transaction, &1)).()
      |> fail?(:utxo_not_found)
      |> same?(state1)
      |> (&Core.exec(bad_transaction2, &1)).()
      |> fail?(:utxo_not_found)
      |> same?(state1)
    end)
  end

  @tag fixtures: [:alice, :bob, :carol, :state_alice_deposit]
  test "can spend change and merge coins", %{
    alice: alice,
    bob: bob,
    carol: carol,
    state_alice_deposit: state
  } do
    state
    |> (&Core.exec(
          create_recover(
            [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
            [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
            0
          ),
          &1
        )).()
    |> success?
    |> (&Core.exec(
          create_recover(
            [%{blknum: @block_interval, txindex: 0, oindex: 0, owner: bob}],
            [%{newowner: carol, amount: 7}],
            0
          ),
          &1
        )).()
    |> success?
    |> (&Core.exec(
          create_recover(
            [%{blknum: @block_interval, txindex: 0, oindex: 1, owner: alice}],
            [%{newowner: carol, amount: 3}],
            0
          ),
          &1
        )).()
    |> success?
    |> (&Core.exec(
          create_recover(
            [
              %{blknum: @block_interval, txindex: 1, oindex: 0, owner: carol},
              %{blknum: @block_interval, txindex: 2, oindex: 0, owner: carol}
            ],
            [%{newowner: alice, amount: 10}],
            0
          ),
          &1
        )).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can spend after block is formed", %{alice: alice, bob: bob, state_alice_deposit: state} do
    next_block_height = 2 * @block_interval
    {:ok, {_, _, _, state}} = Core.form_block(state, @block_interval, next_block_height)

    state
    |> (&Core.exec(
          create_recover(
            [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
            [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
            0
          ),
          &1
        )).()
    |> success?
    |> (&Core.exec(
          create_recover(
            [%{blknum: next_block_height, txindex: 0, oindex: 0, owner: bob}],
            [%{newowner: bob, amount: 7}],
            0
          ),
          &1
        )).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block doesn't unspend", %{alice: alice, bob: bob, state_alice_deposit: state} do
    recovered =
      create_recover(
        [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
        [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
        0
      )

    {:ok, {_, _, _, state}} =
      state
      |> (&Core.exec(recovered, &1)).()
      |> success?
      |> Core.form_block(1 * @block_interval, 2 * @block_interval)

    recovered
    |> Core.exec(state)
    |> fail?(:utxo_not_found)
    |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "spending emits event trigger", %{alice: alice, bob: bob, state_alice_deposit: state} do
    recover =
      create_recover(
        [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
        [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
        0
      )

    assert {:ok, {_, [trigger], _, _}} =
             state |> (&Core.exec(recover, &1)).() |> success?
             |> Core.form_block(1 * @block_interval, 2 * @block_interval)

    assert trigger == %{tx: recover}
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "every spending emits event triggers", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state =
      state
      |> (&Core.exec(
            create_recover(
              [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
              [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
              0
            ),
            &1
          )).()
      |> success?
      |> (&Core.exec(
            create_recover(
              [%{blknum: @block_interval, txindex: 0, oindex: 0, owner: bob}],
              [%{newowner: alice, amount: 7}],
              0
            ),
            &1
          )).()
      |> success?

    assert {:ok, {_, [_trigger1, _trigger2], _, _}} =
             Core.form_block(state, 1 * @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "only successful spending emits event trigger", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state
    |> (&Core.exec(
          create_recover(
            [%{blknum: 1, txindex: 1, oindex: 0, owner: alice}],
            [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
            0
          ),
          &1
        )).()
    |> same?(state)

    assert {:ok, {_, [], _, _}} = Core.form_block(state, 1 * @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :state_empty]
  test "deposits emit event triggers, they don't leak into next block", %{
    alice: alice,
    state_empty: state
  } do
    assert {[trigger], _, state} =
             Core.deposit([%{owner: alice, amount: 4, block_height: @block_interval}], state)

    assert trigger == %{deposit: %{owner: alice, amount: 4}}

    assert {:ok, {_, [], _, _}} = Core.form_block(state, @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "empty blocks emit empty event triggers", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state =
      state
      |> (&Core.exec(
            create_recover(
              [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
              [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
              0
            ),
            &1
          )).()
      |> success?

    next_block_height = 2 * @block_interval

    assert {:ok, {_, [_trigger], _, state}} =
             Core.form_block(state, @block_interval, next_block_height)

    assert {:ok, {_, [], _, _}} =
             Core.form_block(state, next_block_height, next_block_height + @block_interval)
  end

  @tag fixtures: [:stable_alice, :stable_bob, :state_stable_alice_deposit]
  test "forming block puts all transactions in a block", %{
    stable_alice: alice,
    stable_bob: bob,
    state_stable_alice_deposit: state
  } do
    recovered_tx_1 =
      create_recover(
        [
          %{blknum: 1, txindex: 0, oindex: 0, owner: %{priv: bob.priv, addr: alice.addr}},
          %{blknum: 0, txindex: 0, oindex: 0, owner: %{priv: alice.priv, addr: nil}}
        ],
        [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
        0
      )

    recovered_tx_2 =
      create_recover(
        [
          %{
            blknum: @block_interval,
            txindex: 0,
            oindex: 0,
            owner: %{priv: alice.priv, addr: bob.addr}
          },
          %{blknum: 0, txindex: 0, oindex: 0, owner: %{priv: bob.priv, addr: nil}}
        ],
        [%{newowner: alice, amount: 2}, %{newowner: bob, amount: 5}],
        0
      )

    state =
      state
      |> (&Core.exec(recovered_tx_1, &1)).()
      |> success?
      |> (&Core.exec(recovered_tx_2, &1)).()
      |> success?

    expected_block = %Block{
      transactions: [recovered_tx_1, recovered_tx_2],
      hash:
        <<55, 238, 15, 109, 162, 182, 182, 232, 239, 10, 74, 217, 211, 216, 106, 14, 241, 109, 22,
          112, 113, 68, 0, 104, 64, 155, 200, 143, 162, 206, 182, 179>>
    }

    {:ok, {exp_block, _, _, _}} = Core.form_block(state, 1 * @block_interval, 2 * @block_interval)
    assert exp_block == expected_block

    assert {:ok, {^expected_block, _, _, _}} =
             Core.form_block(state, 1 * @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block empty block after a non-empty block", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state =
      state
      |> (&Core.exec(
            create_recover(
              [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
              [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
              0
            ),
            &1
          )).()
      |> success?

    next_block_height = 2 * @block_interval
    {:ok, {_, _, _, state}} = Core.form_block(state, @block_interval, next_block_height)

    expected_block = empty_block()

    {:ok, {^expected_block, _, _, _}} =
      Core.form_block(state, next_block_height, next_block_height + @block_interval)
  end

  @tag fixtures: [:state_empty]
  test "return error when current block numbers do not match when forming block", %{
    state_empty: state
  } do
    assert {:error, :invalid_current_block_number} == Core.form_block(state, 2, 3)
  end

  @tag fixtures: [:state_empty]
  test "no pending transactions at start (no events, empty block, no db updates)", %{
    state_empty: state
  } do
    expected_block = empty_block()

    assert {:ok, {^expected_block, [], [{:put, :block, ^expected_block}], _}} =
             Core.form_block(state, @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "spending produces db updates, that don't leak to next block", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    {:ok, {_, _, db_updates, state}} =
      state
      |> (&Core.exec(
            create_recover(
              [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
              [%{newowner: bob, amount: 7}, %{newowner: alice, amount: 3}],
              0
            ),
            &1
          )).()
      |> success?
      |> Core.form_block(1 * @block_interval, 2 * @block_interval)

    assert [
             {:put, :utxo, new_utxo1},
             {:put, :utxo, new_utxo2},
             {:delete, :utxo, {1, 0, 0}},
             {:put, :block, _}
           ] = db_updates

    assert new_utxo1 == %{{@block_interval, 0, 0} => %{owner: bob.addr, amount: 7}}
    assert new_utxo2 == %{{@block_interval, 0, 1} => %{owner: alice.addr, amount: 3}}

    assert {:ok, {_, _, [{:put, :block, _}], state}} =
             Core.form_block(state, 2 * @block_interval, 3 * @block_interval)

    # check double inputey-spends
    {:ok, {_, _, db_updates2, state}} =
      state
      |> (&Core.exec(
            create_recover(
              [
                %{blknum: @block_interval, txindex: 0, oindex: 0, owner: bob},
                %{blknum: @block_interval, txindex: 0, oindex: 1, owner: alice}
              ],
              [%{newowner: bob, amount: 10}],
              0
            ),
            &1
          )).()
      |> success?
      |> Core.form_block(3 * @block_interval, 4 * @block_interval)

    assert [
             {:put, :utxo, new_utxo},
             {:delete, :utxo, {@block_interval, 0, 0}},
             {:delete, :utxo, {@block_interval, 0, 1}},
             {:put, :block, _}
           ] = db_updates2

    assert new_utxo == %{{3 * @block_interval, 0, 0} => %{owner: bob.addr, amount: 10}}

    assert {:ok, {_, _, [{:put, :block, _}], _}} =
             Core.form_block(state, 4 * @block_interval, 5 * @block_interval)
  end

  @tag fixtures: [:alice, :state_empty]
  test "depositing produces db updates, that don't leak to next block", %{
    alice: alice,
    state_empty: state
  } do
    assert {_, [utxo_update, height_update], state} =
             Core.deposit([%{owner: alice.addr, amount: 10, block_height: 1}], state)

    assert utxo_update == {:put, :utxo, %{{1, 0, 0} => %{owner: alice.addr, amount: 10}}}
    assert height_update == {:put, :last_deposit_block_height, 1}

    assert {:ok, {_, _, [{:put, :block, _}], _}} =
             Core.form_block(state, @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:state_empty]
  test "empty blocks are pushed to db", %{state_empty: state} do
    {:ok, {_, _, db_updates, _}} = Core.form_block(state, @block_interval, 2 * @block_interval)

    is_block_put? = fn {operation, type, _} -> operation == :put && type == :block end
    assert Enum.count(db_updates, is_block_put?) == 1

    expected_block = empty_block()

    assert {:put, :block, ^expected_block} = Enum.find(db_updates, is_block_put?)
  end

  @tag fixtures: [:alice]
  test "utxos get initialized by query result from db and are spendable", %{alice: alice} do
    state =
      Core.extract_initial_state(
        %{{1, 0, 0} => %{amount: 10, owner: alice.addr}},
        0,
        1,
        @block_interval
      )

    state
    |> (&Core.exec(
          create_recover(
            [%{blknum: 1, txindex: 0, oindex: 0, owner: alice}],
            [%{newowner: alice, amount: 7}, %{newowner: alice, amount: 3}],
            0
          ),
          &1
        )).()
    |> success?
  end

  test "core generates the db query" do
    # NOTE: trivial test, considering current behavior, but might evolve... hm
    # FIXME
  end

  defp success?(result) do
    assert {:ok, state} = result
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

  defp empty_block do
    %Block{transactions: [], hash: @empty_block_hash}
  end
end
