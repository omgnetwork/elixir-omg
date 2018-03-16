defmodule OmiseGO.API.State.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.TestHelper

  @empty_block_hash <<39, 51, 229, 15, 82, 110, 194, 250, 25, 162, 43, 49, 232,
                      237, 80, 242, 60, 209, 253, 249, 76, 145, 84, 237, 58, 118, 9,
                      162, 241, 255, 152, 31>>

  deffixture alice() do
    "alicealicealicealice"
  end

  deffixture bob() do
    "bobbobbobbobbobbobbo"
  end

  deffixture carol() do
    "carolcarolcarol"
  end

  deffixture state_empty() do
    Core.extract_initial_state([])
  end

  deffixture state_alice_deposit(state_empty, alice) do
    state_empty
    |> do_deposit(alice, 10)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can spend deposits", %{alice: alice, bob: bob, state_alice_deposit: state} do
    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed
    state =
      %Transaction.Recovered{signed: signed_tx, spender1: alice}
      |> Core.exec(state) |> success?

    signed_tx =
      %Transaction{
        blknum1: 2, txindex1: 0, oindex1: 1, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 3, newowner2: 0, amount2: 0, fee: 0,
      }
      |> TestHelper.signed

    %Transaction.Recovered{signed: signed_tx, spender1: alice}
    |> Core.exec(state) |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend nonexistent", %{alice: alice, bob: bob, state_alice_deposit: state} do
    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 1, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed
    %Transaction.Recovered{signed: signed_tx, spender1: alice}
    |> Core.exec(state) |> fail?(:utxo_not_found) |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "amounts must add up", %{alice: alice, bob: bob, state_alice_deposit: state} do
    tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 8, newowner2: alice, amount2: 3, fee: 0,
      }
    assert_amounts_dont_add_up(state, tx, alice, Transaction.zero_address())

    #spending utxo with fee
    tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 8, newowner2: alice, amount2: 2, fee: 1,
      }
    assert_amounts_dont_add_up(state, tx, alice, Transaction.zero_address())

    #spending from second input
    tx =
      %Transaction{
        blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 1, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 8, newowner2: alice, amount2: 3, fee: 0,
      }
    assert_amounts_dont_add_up(state, tx, Transaction.zero_address(), alice)

    #spending both outputs
    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 2, newowner2: alice, amount2: 8, fee: 0,
      }
      |> TestHelper.signed

    state =
      %Transaction.Recovered{signed: signed_tx, spender1: alice}
      |> Core.exec(state) |> success?

    tx = %Transaction{
      blknum1: 2, txindex1: 0, oindex1: 0, blknum2: 2, txindex2: 0, oindex2: 1,
      newowner1: alice, amount1: 8, newowner2: bob, amount2: 3, fee: 0,
    }
    assert_amounts_dont_add_up(state, tx, bob, alice)
  end

  defp assert_amounts_dont_add_up(state, transaction, spender1, spender2) do
    signed_tx = transaction |> TestHelper.signed
    %Transaction.Recovered{signed: signed_tx, spender1: spender1, spender2: spender2}
    |> Core.exec(state) |> fail?(:amounts_dont_add_up) |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend other people's funds", %{alice: alice, bob: bob, state_alice_deposit: state}  do
    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 8, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed
    %Transaction.Recovered{signed: signed_tx, spender1: bob}
    |> Core.exec(state) |> fail?(:incorrect_spender) |> same?(state)

    signed_tx =
      %Transaction{
        blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 1, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 8, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed

    %Transaction.Recovered{signed: signed_tx, spender1: bob}
    |> Core.exec(state) |> fail?(:incorrect_spender) |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend spent", %{alice: alice, bob: bob, state_alice_deposit: state}  do
    # FIXME dry - we need many cases since attempt to spend spend might be done in 4 different ways
    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed
    state1 =
      %Transaction.Recovered{signed: signed_tx, spender1: alice}
      |> Core.exec(state) |> success?

    signed_tx =
      %Transaction{
        blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 1, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed
    state2 =
      %Transaction.Recovered{signed: signed_tx, spender2: alice}
      |> Core.exec(state) |> success?

    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed
    [state1, state2]
    |> Enum.map(fn state ->
      %Transaction.Recovered{signed: signed_tx, spender1: alice}
      |> Core.exec(state) |> fail?(:utxo_not_found) |> same?(state)
    end)

    signed_tx = %Transaction{
      blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 1, txindex2: 0, oindex2: 0,
      newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
    }
    |> TestHelper.signed
    [state1, state2]
    |> Enum.map(fn state ->
      %Transaction.Recovered{signed: signed_tx, spender2: alice}
      |> Core.exec(state) |> fail?(:utxo_not_found) |> same?(state)
    end)
  end

  @tag fixtures: [:alice, :bob, :carol, :state_alice_deposit]
  test "can spend change and merge coins", %{alice: alice, bob: bob, carol: carol, state_alice_deposit: state}  do
    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed

    state =
      %Transaction.Recovered{signed: signed_tx, spender1: alice}
      |> Core.exec(state) |> success?

    signed_tx =
      %Transaction{
        blknum1: 2, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: carol, amount1: 7, newowner2: 0, amount2: 0, fee: 0,
      }
      |> TestHelper.signed
    state =
      %Transaction.Recovered{signed: signed_tx, spender1: bob}
      |> Core.exec(state) |> success?

    signed_tx =
      %Transaction{
        blknum1: 2, txindex1: 0, oindex1: 1, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: carol, amount1: 3, newowner2: 0, amount2: 0, fee: 0,
      }
      |> TestHelper.signed
    state =
      %Transaction.Recovered{signed: signed_tx, spender1: alice}
      |> Core.exec(state) |> success?

    signed_tx =
      %Transaction{
        blknum1: 2, txindex1: 1, oindex1: 0, blknum2: 2, txindex2: 2, oindex2: 0,
        newowner1: alice, amount1: 10, newowner2: 0, amount2: 0, fee: 0,
      }
      |> TestHelper.signed
    %Transaction.Recovered{signed: signed_tx, spender1: carol, spender2: carol}
    |> Core.exec(state) |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can spend after block is formed", %{alice: alice, bob: bob, state_alice_deposit: state}  do
    {_, _, _, state} = Core.form_block(state)

    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed
    state =
      %Transaction.Recovered{signed: signed_tx, spender1: alice}
      |> Core.exec(state) |> success?

    signed_tx =
      %Transaction{
        blknum1: 3, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: 0, amount2: 0, fee: 0,
      }
      |> TestHelper.signed
    %Transaction.Recovered{signed: signed_tx, spender1: bob}
    |> Core.exec(state) |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block doesn't unspend", %{alice: alice, bob: bob, state_alice_deposit: state} do
    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed

    state =
      %Transaction.Recovered{signed: signed_tx, spender1: alice}
      |> Core.exec(state) |> success?

    {_, _, _, state} = Core.form_block(state)

    %Transaction.Recovered{signed: signed_tx, spender1: alice}
    |> Core.exec(state) |> fail?(:utxo_not_found)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "spending emits event trigger", %{alice: alice, bob: bob, state_alice_deposit: state} do
    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed

    state =
      %Transaction.Recovered{signed: signed_tx, spender1: alice}
      |> Core.exec(state) |> success?

    assert {_, [trigger], _, _} = Core.form_block(state)

    assert trigger == %{tx: signed_tx}
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "every spending emits event triggers", %{alice: alice, bob: bob, state_alice_deposit: state} do
    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed
    state =
      %Transaction.Recovered{signed: signed_tx, spender1: alice}
      |> Core.exec(state) |> success?

    signed_tx =
      %Transaction{
        blknum1: 2, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: alice, amount1: 7, newowner2: 0, amount2: 0, fee: 0,
      }
      |> TestHelper.signed
    state =
      %Transaction.Recovered{signed: signed_tx, spender1: bob}
      |> Core.exec(state) |> success?

    assert {_, [_trigger1, _trigger2], _, _} = Core.form_block(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "only successful spending emits event trigger", %{alice: alice, bob: bob, state_alice_deposit: state} do
    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 1, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed
    state =
      %Transaction.Recovered{signed: signed_tx, spender1: alice}
      |> Core.exec(state) |> same?(state)

    assert {_, [], _, _} = Core.form_block(state)
  end

  @tag fixtures: [:alice, :state_empty]
  test "deposits emit event triggers, they don't leak into next block", %{alice: alice, state_empty: state} do
    assert {[trigger], _, state} = Core.deposit(alice, 4, state)

    assert trigger == %{deposit: %{owner: alice, amount: 4}}

    assert {_, [], _, _} = Core.form_block(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "empty blocks emit empty event triggers", %{alice: alice, bob: bob, state_alice_deposit: state} do
    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      }
      |> TestHelper.signed
    state =
      %Transaction.Recovered{signed: signed_tx, spender1: alice}
      |> Core.exec(state) |> success?

    assert {_, [_trigger], _, state} = Core.form_block(state)
    assert {_, [], _, _} = Core.form_block(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block puts all transactions in a block",
     %{alice: alice, bob: bob, state_alice_deposit: state} do

    signed_tx_1 =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0
      }
      |> TestHelper.signed
    state =
      %Transaction.Recovered{signed: signed_tx_1, spender1: alice}
      |> Core.exec(state) |> success?

    signed_tx_2 =
      %Transaction{
        blknum1: 2, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: alice, amount1: 2, newowner2: bob, amount2: 5, fee: 0
      }
      |> TestHelper.signed
    state =
      %Transaction.Recovered{signed: signed_tx_2, spender1: bob}
      |> Core.exec(state) |> success?

    expected_block =
      %Block{
        transactions: [signed_tx_1, signed_tx_2],
        hash: <<222, 21, 36, 237, 108, 161, 96, 234, 25, 28, 102, 22,
                210, 192, 45, 101, 109, 90, 220, 253, 39, 134, 197, 129, 139,
                135, 120, 214, 203, 233, 76, 186>>
      }
    {^expected_block, _, _, _} = Core.form_block(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block empty block after a non-empty block",
       %{alice: alice, bob: bob, state_alice_deposit: state} do
    signed_tx_1 =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0
      }
      |> TestHelper.signed
    state =
      %Transaction.Recovered{signed: signed_tx_1, spender1: alice}
      |> Core.exec(state) |> success?

    {_, _, _, state} = Core.form_block(state)

    expected_block = %Block{transactions: [], hash: @empty_block_hash}
    {^expected_block, _, _, _} = Core.form_block(state)
  end

  @tag fixtures: [:state_empty]
  test "no pending transactions at start (no events, empty block, no db updates)", %{state_empty: state} do
    expected_block = %Block{transactions: [], hash: @empty_block_hash}
    {^expected_block, _, _, _} = Core.form_block(state)
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
    #                newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
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
    #                newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
    #   |> Core.exec(state) |> success?

  end

  test "core generates the db query" do
    # NOTE: trivial test, considering current behavior, but might evolve... hm
    # FIXME
    assert "correct query" == Core.get_state_fetching_query()
  end

  # TODO: other?

  defp do_deposit(state, owner, amount) do
    {_, _, new_state} =
      Core.deposit(owner, amount, state)
    new_state
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
