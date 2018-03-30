defmodule OmiseGO.API.State.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.Transaction

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
        blknum1: 2, txindex1: 0, oindex1: 1, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 3, newowner2: 0, amount2: 0, fee: 0,
      }

    %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
      |> Core.exec(state) |> success?
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
    # FIXME
    # raw_tx =
    #   %Transaction{
    #     blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
    #     newowner1: alice.addr, amount1: 8, newowner2: bob.addr, amount2: 3, fee: 0,
    #   }
    #
    # signed_tx_hash =
    #   raw_tx
    #   |> Transaction.signed(alice.priv, bob.priv)
    #   |> Transaction.Signed.hash
    #
    # assert_amounts_dont_add_up(state, raw_tx, signed_tx_hash, alice.addr, bob.addr)
    #
    # #spending utxo with fee
    # raw_tx =
    #   %Transaction{
    #     blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 1, oindex2: 0,
    #     newowner1: bob.addr, amount1: 8, newowner2: alice.addr, amount2: 2, fee: 1,
    #   }
    #
    #
    # signed_tx_hash =
    #   raw_tx
    #   |> Transaction.signed(alice.priv, bob.priv)
    #   |> Transaction.Signed.hash
    #
    # assert_amounts_dont_add_up(state, raw_tx, signed_tx_hash, alice.addr, Transaction.zero_address())

    # #spending from second input
    # raw_tx =
    #   %Transaction{
    #     blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 1, txindex2: 0, oindex2: 0,
    #     newowner1: bob.addr, amount1: 8, newowner2: alice.addr, amount2: 3, fee: 0,
    #   }
    #
    # signed_tx_hash =
    #   raw_tx
    #   |> Transaction.signed(alice.priv, bob.priv)
    #   |> Transaction.Signed.hash
    #
    # assert_amounts_dont_add_up(state, raw_tx, signed_tx_hash, Transaction.zero_address(), alice.addr)
    #
    # #spending both outputs
    # raw_tx =
    #   %Transaction{
    #     blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
    #     newowner1: bob.addr, amount1: 2, newowner2: alice.addr, amount2: 8, fee: 0,
    #   }
    #
    # signed_tx_hash =
    #   raw_tx
    #   |> Transaction.signed(alice.priv, bob.priv)
    #   |> Transaction.Signed.hash
    #
    # state =
    #   %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
    #   |> Core.exec(state) |> success?
    #
    # raw_tx = %Transaction{
    #   blknum1: 2, txindex1: 0, oindex1: 0, blknum2: 2, txindex2: 0, oindex2: 1,
    #   newowner1: alice.addr, amount1: 8, newowner2: bob.addr, amount2: 3, fee: 0,
    # }
    #
    # signed_tx_hash =
    #   raw_tx
    #   |> Transaction.signed(alice.priv, bob.priv)
    #   |> Transaction.Signed.hash
    #
    # assert_amounts_dont_add_up(state, raw_tx, signed_tx_hash, bob.addr, alice.addr)
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
        blknum1: 2, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: carol.addr, amount1: 7, newowner2: 0, amount2: 0, fee: 0,
      }

    state =
      %Transaction.Recovered{raw_tx: raw_tx, spender1: bob.addr}
      |> Core.exec(state) |> success?

    raw_tx =
      %Transaction{
        blknum1: 2, txindex1: 0, oindex1: 1, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: carol.addr, amount1: 3, newowner2: 0, amount2: 0, fee: 0,
      }

    state =
      %Transaction.Recovered{raw_tx: raw_tx, spender1: alice.addr}
      |> Core.exec(state) |> success?

    raw_tx =
      %Transaction{
        blknum1: 2, txindex1: 1, oindex1: 0, blknum2: 2, txindex2: 2, oindex2: 0,
        newowner1: alice.addr, amount1: 10, newowner2: 0, amount2: 0, fee: 0,
      }

    %Transaction.Recovered{raw_tx: raw_tx, spender1: carol.addr, spender2: carol.addr}
    |> Core.exec(state) |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can spend after block is formed", %{alice: alice, bob: bob, state_alice_deposit: state}  do
    {:ok, {_, _, _, state}} = Core.form_block(state.height, state.height + 1, state)

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
        blknum1: 3, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: 0, amount2: 0, fee: 0,
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
      |> Transaction.signed(alice.priv, bob.priv)
      |> Transaction.Signed.hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
      |> Core.exec(state) |> success?

    {:ok, {_, _, _, state}} = Core.form_block(state.height, state.height + 1, state)

    %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
    |> Core.exec(state) |> fail?(:utxo_not_found)
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
      |> Transaction.signed(alice.priv, bob.priv)
      |> Transaction.Signed.hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
      |> Core.exec(state) |> success?

    assert {:ok, {_, [trigger], _, _}} = Core.form_block(state.height, state.height + 1, state)

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
      |> Transaction.signed(alice.priv, bob.priv)
      |> Transaction.Signed.hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
      |> Core.exec(state) |> success?

    raw_tx =
      %Transaction{
        blknum1: 2, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: alice.addr, amount1: 7, newowner2: 0, amount2: 0, fee: 0,
      }

    signed_tx_hash =
      raw_tx
      |> Transaction.signed(alice.priv, bob.priv)
      |> Transaction.Signed.hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: bob.addr}
      |> Core.exec(state) |> success?

    assert {:ok, {_, [_trigger1, _trigger2], _, _}} = Core.form_block(state.height, state.height + 1, state)
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

    assert {:ok, {_, [], _, _}} = Core.form_block(state.height, state.height + 1, state)
  end

  @tag fixtures: [:alice, :state_empty]
  test "deposits emit event triggers, they don't leak into next block", %{alice: alice, state_empty: state} do
    assert {[trigger], _, state} = Core.deposit(alice, 4, state)

    assert trigger == %{deposit: %{owner: alice, amount: 4}}

    assert {:ok, {_, [], _, _}} = Core.form_block(state.height, state.height + 1, state)
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
      |> Transaction.signed(alice.priv, bob.priv)
      |> Transaction.Signed.hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
      |> Core.exec(state) |> success?

    assert {:ok, {_, [_trigger], _, state}} = Core.form_block(state.height, state.height + 1, state)
    assert {:ok, {_, [], _, _}} = Core.form_block(state.height, state.height + 1, state)
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
      |> Transaction.signed(bob.priv, alice.priv)
      |> Transaction.Signed.hash

    recovered_tx_1 =
      %Transaction.Recovered{raw_tx: raw_tx_1, signed_tx_hash: signed_tx_hash_1, spender1: alice.addr}

    state =
      recovered_tx_1
      |> Core.exec(state) |> success?

    raw_tx_2 =
      %Transaction{
        blknum1: 2, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: alice.addr, amount1: 2, newowner2: bob.addr, amount2: 5, fee: 0
      }

    signed_tx_hash_2 =
      raw_tx_2
      |> Transaction.signed(alice.priv, bob.priv)
      |> Transaction.Signed.hash

    recovered_tx_2 =
      %Transaction.Recovered{raw_tx: raw_tx_2, signed_tx_hash: signed_tx_hash_2, spender1: bob.addr}

    state =
      recovered_tx_2
      |> Core.exec(state) |> success?

    expected_block =
      %Block{
        transactions: [recovered_tx_1, recovered_tx_2],
        hash: <<202, 27, 137, 247, 249, 36, 44, 110, 164, 9, 65, 161, 33, 136,
                217, 47, 243, 72, 189, 78, 23, 158, 2, 142, 136, 147, 210,
                40, 225, 224, 68, 155>>
      }
    {:ok, {^expected_block, _, _, _}} = Core.form_block(state.height, state.height + 1, state)
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
      |> Transaction.signed(alice.priv, bob.priv)
      |> Transaction.Signed.hash

    state =
      %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash, spender1: alice.addr}
      |> Core.exec(state) |> success?

    {:ok, {_, _, _, state}} = Core.form_block(state.height, state.height + 1, state)

    expected_block = %Block{transactions: [], hash: @empty_block_hash}
    {:ok, {^expected_block, _, _, _}} = Core.form_block(state.height, state.height + 1, state)
  end

  @tag fixtures: [:state_empty]
  test "return error when current block numbers do not match when forming block", %{state_empty: state} do
    assert {:error, :invalid_current_block_number} == Core.form_block(2, 3, state)
  end

  @tag fixtures: [:state_empty]
  test "no pending transactions at start (no events, empty block, no db updates)", %{state_empty: state} do
    expected_block = %Block{transactions: [], hash: @empty_block_hash}
    {:ok, {^expected_block, [], [], _}} = Core.form_block(state.height, state.height + 1, state)
  end

  test "spending produces db updates, that don't leak to next block" do
    # FIXME
    # FIXME check new tx and block in db_updates

    # {_, _, [], _} = Core.form_block(state)
  end

  test "depositing produces db updates, that don't leak to next block" do
    # FIXME
    # FIXME check block and transaction in db updates

    # {_, _, [], _} = Core.form_block(state)
  end

  test "spending removes/adds utxos from db" do

    # FIXME
    # FIXME check removal/add of utxos
  end

  test "empty blocks are pushed to db" do
    # {_, _, db_updates, _} = Core.form_block(state)

    # FIXME empty block in db_udates and height bump
  end

  test "blocks with deposits and spends are pushed to db and events properly" do
    # alice = "" # FIXME
    # bob = ""
    #
    # state = "alice deposited"
    #
    # state =
    #   %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
    #                newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0}
    #   |> Core.exec(state) |> success?
    # {[deposit_trigger], [deposit_db_update], state} = Core.deposit(alice, 4, state)
    #
    # {block, [spend_trigger], [spend_db_update], _} = Core.form_block(state)

    # FIXME check both ok in db and events and block
  end

  test "utxos get initialized by query result from db and are spendable" do
    # alice = "" # FIXME
    # bob = ""

    # TODO: use actual code to generate query result for utxos
    # state = Core.extract_initial_state("utxo1, utxo2 etc")
    # state =
    #   %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
    #                newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0}
    #   |> Core.exec(state) |> success?

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

end
