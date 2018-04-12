defmodule OmiseGO.API.State.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.Transaction

  @block_interval 1000
  @empty_block_hash <<39, 51, 229, 15, 82, 110, 194, 250, 25, 162, 43, 49, 232,
                      237, 80, 242, 60, 209, 253, 249, 76, 145, 84, 237, 58, 118, 9,
                      162, 241, 255, 152, 31>>

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can spend deposits", %{alice: alice, bob: bob, state_alice_deposit: state} do

    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    state =
      %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
      |> Core.exec(state) |> success?

    raw_tx =
      %Transaction{
        blknum1: @block_interval, txindex1: 0, oindex1: 1, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 3, newowner2: 0, amount2: 0, fee: 0,
      }

    %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
      |> Core.exec(state) |> success?
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can spend a batch of deposits", %{alice: alice, bob: bob, state_empty: state} do
    deposits = [
      %{owner: alice.addr, amount: 10, block_height: 1},
      %{owner: bob.addr, amount: 20, block_height: 2}
    ]

    {_, _, state} = Core.deposit(deposits, state)

    raw_tx_1 =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 10, newowner2: <<>>, amount2: 0, fee: 0,
      }

    signed_tx_hash_alice =
      raw_tx_1
      |> Transaction.sign(alice.priv, <<>>)
      |> Transaction.Signed.signed_hash

      %Transaction.Recovered{raw_tx: raw_tx_1, signed_tx_hash: signed_tx_hash_alice, spender1: alice.addr}
        |> Core.exec(state) |> success?

      raw_tx_2 =
        %Transaction{
          blknum1: 2, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
          newowner1: alice.addr, amount1: 20, newowner2: <<>>, amount2: 0, fee: 0,
        }

      signed_tx_hash_bob =
        raw_tx_2
        |> Transaction.sign(bob.priv, <<>>)
        |> Transaction.Signed.signed_hash

      %Transaction.Recovered{raw_tx: raw_tx_2, signed_tx_hash: signed_tx_hash_bob, spender1: bob.addr}
        |> Core.exec(state) |> success?
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "ignores deposits from blocks not higher than the block with the last previously received deposit",
    %{alice: alice, bob: bob, state_empty: state} do
      deposits = [
        %{owner: alice.addr, amount: 20, block_height: 2}
      ]
      assert {_, [_, {:put, :last_deposit_block_height, 2}], state} = Core.deposit(deposits, state)

      assert {[], [], ^state} = Core.deposit([%{owner: bob.addr, amount: 20, block_height: 1}], state)
  end

  @tag fixtures: [:bob]
  test "ignores deposits from blocks not higher than the deposit height read from db", %{bob: bob} do
      state = Core.extract_initial_state(%{}, 0, 1, @block_interval)

      assert {[], [], ^state} = Core.deposit([%{owner: bob.addr, amount: 20, block_height: 1}], state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend nonexistent", %{alice: alice, bob: bob, state_alice_deposit: state} do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 1, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
    |> Core.exec(state) |> fail?(:utxo_not_found) |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "amounts must add up", %{alice: alice, bob: bob, state_alice_deposit: state} do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: alice.addr, amount1: 8, newowner2: bob.addr, amount2: 3, fee: 0,
      }

    signed_tx_hash =
      raw_tx
      |> Transaction.sign(alice.priv, <<>>)
      |> Transaction.Signed.signed_hash

    assert_amounts_dont_add_up(state, raw_tx, signed_tx_hash, alice.addr, nil)

    #spending utxo with fee
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 1, oindex2: 0,
        newowner1: bob.addr, amount1: 8, newowner2: alice.addr, amount2: 2, fee: 1,
      }

    signed_tx_hash =
      raw_tx
      |> Transaction.sign(alice.priv, <<>>)
      |> Transaction.Signed.signed_hash

    assert_amounts_dont_add_up(state, raw_tx, signed_tx_hash, alice.addr, nil)

    #spending from second input
    raw_tx =
      %Transaction{
        blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 1, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 8, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    signed_tx_hash =
      raw_tx
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.signed_hash

    assert_amounts_dont_add_up(state, raw_tx, signed_tx_hash, nil, alice.addr)

    #spending both outputs
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 2, newowner2: alice.addr, amount2: 8, fee: 0,
      }

    signed_tx_hash =
      raw_tx
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.signed_hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
      |> Core.exec(state) |> success?

    raw_tx = %Transaction{
      blknum1: @block_interval, txindex1: 0, oindex1: 0,
      blknum2: @block_interval, txindex2: 0, oindex2: 1,
      newowner1: alice.addr, amount1: 8, newowner2: bob.addr, amount2: 3, fee: 0,
    }

    signed_tx_hash =
      raw_tx
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.signed_hash

    assert_amounts_dont_add_up(state, raw_tx, signed_tx_hash, bob.addr, alice.addr)
  end

  defp assert_amounts_dont_add_up(state, raw_tx, signed_tx_hash, spender1, spender2) do
    %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: spender1, spender2: spender2}
    |> Core.exec(state) |> fail?(:amounts_dont_add_up) |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend other people's funds", %{alice: alice, bob: bob, state_alice_deposit: state}  do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 8, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    %Transaction.Recovered{raw_tx: raw_tx, spender1: bob.addr}
    |> Core.exec(state) |> fail?(:incorrect_spender) |> same?(state)

    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 1, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 8, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    %Transaction.Recovered{raw_tx: raw_tx, spender1: bob.addr}
    |> Core.exec(state) |> fail?(:incorrect_spender) |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend spent", %{alice: alice, bob: bob, state_alice_deposit: state}  do
    # FIXME dry - we need many cases since attempt to spend spend might be done in 4 different ways
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    state1 =
      %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
      |> Core.exec(state) |> success?

    raw_tx =
      %Transaction{
        blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 1, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    state2 =
      %Transaction.Recovered{raw_tx: raw_tx, spender2: alice.addr}
      |> Core.exec(state) |> success?

    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    [state1, state2]
    |> Enum.map(fn state ->
      %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
      |> Core.exec(state) |> fail?(:utxo_not_found) |> same?(state)
    end)

    raw_tx = %Transaction{
      blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 1, txindex2: 0, oindex2: 0,
      newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
    }

    [state1, state2]
    |> Enum.map(fn state ->
      %Transaction.Recovered{raw_tx: raw_tx, spender2: alice.addr}
      |> Core.exec(state) |> fail?(:utxo_not_found) |> same?(state)
    end)
  end

  @tag fixtures: [:alice, :bob, :carol, :state_alice_deposit]
  test "can spend change and merge coins", %{alice: alice, bob: bob, carol: carol, state_alice_deposit: state}  do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    state =
      %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
      |> Core.exec(state) |> success?

    raw_tx =
      %Transaction{
        blknum1: @block_interval, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: carol.addr, amount1: 7, newowner2: 0, amount2: 0, fee: 0,
      }

    state =
      %Transaction.Recovered{raw_tx: raw_tx, spender1: bob.addr}
      |> Core.exec(state) |> success?

    raw_tx =
      %Transaction{
        blknum1: @block_interval, txindex1: 0, oindex1: 1, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: carol.addr, amount1: 3, newowner2: 0, amount2: 0, fee: 0,
      }

    state =
      %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
      |> Core.exec(state) |> success?

    raw_tx =
      %Transaction{
        blknum1: @block_interval, txindex1: 1, oindex1: 0, blknum2: @block_interval, txindex2: 2, oindex2: 0,
        newowner1: alice.addr, amount1: 10, newowner2: 0, amount2: 0, fee: 0,
      }

    %Transaction.Recovered{raw_tx: raw_tx, spender1: carol.addr, spender2: carol.addr}
    |> Core.exec(state) |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can spend after block is formed", %{alice: alice, bob: bob, state_alice_deposit: state} do
    next_block_height = 2 * @block_interval
    {:ok, {_, _, _, state}} = Core.form_block(state, @block_interval, next_block_height)

    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    state =
      %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
      |> Core.exec(state) |> success?

    raw_tx =
      %Transaction{
        blknum1: next_block_height, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: 0, amount2: 0, fee: 0,
      }

    %Transaction.Recovered{raw_tx: raw_tx, spender1: bob.addr}
    |> Core.exec(state) |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block doesn't unspend", %{alice: alice, bob: bob, state_alice_deposit: state} do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    signed_tx_hash =
      raw_tx
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.signed_hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
      |> Core.exec(state) |> success?

    {:ok, {_, _, _, state}} = Core.form_block(state, 1 * @block_interval, 2 * @block_interval)

    %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
    |> Core.exec(state) |> fail?(:utxo_not_found) |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "spending emits event trigger", %{alice: alice, bob: bob, state_alice_deposit: state} do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    signed_tx_hash =
      raw_tx
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.signed_hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
      |> Core.exec(state) |> success?

    assert {:ok, {_, [trigger], _, _}} = Core.form_block(state, 1 * @block_interval, 2 * @block_interval)

    assert trigger ==
      %{tx:
        %Transaction.Recovered{raw_tx: raw_tx,
          signed_tx_hash: signed_tx_hash,
          spender1: alice.addr}
      }
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "every spending emits event triggers", %{alice: alice, bob: bob, state_alice_deposit: state} do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    signed_tx_hash =
      raw_tx
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.signed_hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
      |> Core.exec(state) |> success?

    raw_tx =
      %Transaction{
        blknum1: @block_interval, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: alice.addr, amount1: 7, newowner2: 0, amount2: 0, fee: 0,
      }

    signed_tx_hash =
      raw_tx
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.signed_hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: bob.addr}
      |> Core.exec(state) |> success?

    assert {:ok, {_, [_trigger1, _trigger2], _, _}} = Core.form_block(state, 1 * @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "only successful spending emits event trigger", %{alice: alice, bob: bob, state_alice_deposit: state} do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 1, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    state =
      %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
      |> Core.exec(state) |> same?(state)

    assert {:ok, {_, [], _, _}} = Core.form_block(state, 1 * @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :state_empty]
  test "deposits emit event triggers, they don't leak into next block", %{alice: alice, state_empty: state} do
    assert {[trigger], _, state} = Core.deposit([%{owner: alice, amount: 4, block_height: @block_interval}], state)

    assert trigger == %{deposit: %{owner: alice, amount: 4}}

    assert {:ok, {_, [], _, _}} = Core.form_block(state, @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "empty blocks emit empty event triggers", %{alice: alice, bob: bob, state_alice_deposit: state} do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    signed_tx_hash =
      raw_tx
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.signed_hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
      |> Core.exec(state) |> success?

    next_block_height = 2 * @block_interval
    assert {:ok, {_, [_trigger], _, state}} = Core.form_block(state, @block_interval, next_block_height)
    assert {:ok, {_, [], _, _}} = Core.form_block(state, next_block_height, next_block_height + @block_interval)
  end

  @tag fixtures: [:stable_alice, :stable_bob, :state_stable_alice_deposit]
  test "forming block puts all transactions in a block",
     %{stable_alice: alice, stable_bob: bob, state_stable_alice_deposit: state} do

    raw_tx_1 =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0
      }

    signed_tx_hash_1 =
      raw_tx_1
      |> Transaction.sign(bob.priv, alice.priv)
      |> Transaction.Signed.signed_hash

    recovered_tx_1 =
      %Transaction.Recovered{raw_tx: raw_tx_1, signed_tx_hash: signed_tx_hash_1, spender1: alice.addr}

    state =
      recovered_tx_1
      |> Core.exec(state) |> success?

    raw_tx_2 =
      %Transaction{
        blknum1: @block_interval, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: alice.addr, amount1: 2, newowner2: bob.addr, amount2: 5, fee: 0
      }

    signed_tx_hash_2 =
      raw_tx_2
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.signed_hash

    recovered_tx_2 =
      %Transaction.Recovered{raw_tx: raw_tx_2, signed_tx_hash: signed_tx_hash_2, spender1: bob.addr}

    state =
      recovered_tx_2
      |> Core.exec(state) |> success?

    expected_block =
      %Block{
        transactions: [recovered_tx_1, recovered_tx_2],
        hash: <<55, 238, 15, 109, 162, 182, 182, 232, 239, 10, 74, 217,
                  211, 216, 106, 14, 241, 109, 22, 112, 113, 68, 0, 104, 64,
                  155, 200, 143, 162, 206, 182, 179>>
      }
    assert {:ok, {^expected_block, _, _, _}} = Core.form_block(state, 1 * @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block empty block after a non-empty block",
       %{alice: alice, bob: bob, state_alice_deposit: state} do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0
      }

    signed_tx_hash =
      raw_tx
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.signed_hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
      |> Core.exec(state) |> success?

    next_block_height = 2 * @block_interval
    {:ok, {_, _, _, state}} = Core.form_block(state, @block_interval, next_block_height)

    expected_block = empty_block()
    {:ok, {^expected_block, _, _, _}} = Core.form_block(state, next_block_height, next_block_height + @block_interval)
  end

  @tag fixtures: [:state_empty]
  test "return error when current block numbers do not match when forming block", %{state_empty: state} do
    assert {:error, :invalid_current_block_number} == Core.form_block(state, 2, 3)
  end

  @tag fixtures: [:state_empty]
  test "no pending transactions at start (no events, empty block, no db updates)", %{state_empty: state} do
    expected_block = empty_block()

    assert {:ok, {^expected_block, [], [{:put, :block, ^expected_block}], _}} =
      Core.form_block(state, @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "spending produces db updates, that don't leak to next block",
       %{alice: alice, bob: bob, state_alice_deposit: state} do
    raw_tx_1 =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0
      }

    signed_tx_hash_1 =
      raw_tx_1
      |> Transaction.sign(alice.priv, <<>>)
      |> Transaction.Signed.signed_hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx_1, signed_tx_hash: signed_tx_hash_1, spender1: alice.addr}
      |> Core.exec(state) |> success?

    {:ok, {_, _, db_updates, state}} =
      Core.form_block(state, 1 * @block_interval, 2 * @block_interval)

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
    raw_tx_2 =
      %Transaction{
        blknum1: @block_interval, txindex1: 0, oindex1: 0, blknum2: @block_interval, txindex2: 0, oindex2: 1,
        newowner1: bob.addr, amount1: 10, newowner2: 0, amount2: 0, fee: 0
      }

    signed_tx_hash_2 =
      raw_tx_2
      |> Transaction.sign(bob.priv, alice.priv)
      |> Transaction.Signed.signed_hash

    state =
      %Transaction.Recovered{
        raw_tx: raw_tx_2,
        signed_tx_hash: signed_tx_hash_2,
        spender1: bob.addr,
        spender2: alice.addr
      }
      |> Core.exec(state)
      |> success?

    {:ok, {_, _, db_updates2, state}} =
      Core.form_block(state, 3 * @block_interval, 4 * @block_interval)

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
  test "depositing produces db updates, that don't leak to next block", %{alice: alice, state_empty: state} do

    assert {_, [utxo_update, height_update], state} =
      Core.deposit([%{owner: alice.addr, amount: 10, block_height: 1}], state)

    assert utxo_update == {:put, :utxo, %{{1, 0, 0} => %{owner: alice.addr, amount: 10}}}
    assert height_update == {:put, :last_deposit_block_height, 1}

    assert {:ok, {_, _, [{:put, :block, _}], _}} = Core.form_block(state, @block_interval, 2 * @block_interval)
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

    state = Core.extract_initial_state(%{{1, 0, 0} => %{amount: 10, owner: alice.addr}}, 0, 1, @block_interval)

    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: alice.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
    |> Core.exec(state) |> success?
  end

  test "core generates the db query" do
    # NOTE: trivial test, considering current behavior, but might evolve... hm
    # FIXME
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "spends utxo when exiting", %{alice: alice, state_alice_deposit: state} do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: alice.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    state =
      %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
      |> Core.exec(state) |> success?

    expected_owner = alice.addr
    {[%{exit: %{owner: ^expected_owner, block_height: @block_interval, txindex: 0, oindex: 0}},
      %{exit: %{owner: ^expected_owner, block_height: @block_interval, txindex: 0, oindex: 1}}],
     [{:delete, :utxo, {@block_interval, 0, 0}}, {:delete, :utxo, {@block_interval, 0, 1}}],
     state} =
      [%{owner: alice.addr, block_height: @block_interval, txindex: 0, oindex: 0},
       %{owner: alice.addr, block_height: @block_interval, txindex: 0, oindex: 1}]
      |> Core.exit_utxos(state)

    exited_spend_1 = %Transaction{
      blknum1: @block_interval, txindex1: 1, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
      newowner1: alice.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
    }
    %Transaction.Recovered{raw_tx: exited_spend_1, spender1: alice.addr}
    |> Core.exec(state) |> fail?(:utxo_not_found) |> same?(state)

    exited_spend_2 = %Transaction{
      blknum1: @block_interval, txindex1: 1, oindex1: 1, blknum2: 0, txindex2: 0, oindex2: 0,
      newowner1: alice.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
    }
    %Transaction.Recovered{raw_tx: exited_spend_2, spender1: alice.addr}
    |> Core.exec(state) |> fail?(:utxo_not_found) |> same?(state)
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "does not change when exiting spent utxo", %{alice: alice, state_alice_deposit: state} do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: alice.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }

    state =
      %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
      |> Core.exec(state) |> success?

    {[], [], ^state} =
      [%{owner: alice.addr, block_height: 1, txindex: 0, oindex: 0}]
      |> Core.exit_utxos(state)
  end

  @tag fixtures: [:state_empty]
  test "does not change when exiting non-existent utxo", %{state_empty: state} do
    {[], [], ^state} =
      [%{owner: "owner", block_height: 1, txindex: 0, oindex: 0}]
      |> Core.exit_utxos(state)
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
