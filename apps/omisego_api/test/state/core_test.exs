defmodule OmiseGO.API.State.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.Transaction

  deffixture alice() do
    "alice"
  end

  deffixture bob() do
    "bob"
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

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

    %Transaction{blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                 newowner1: bob, amount1: 7, newowner2: 0, amount2: 0, fee: 0}
    |> Core.exec(state) |> success?
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can't spend nonexistent", %{alice: alice, bob: bob, state_empty: state} do

    %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                 newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
    |> Core.exec(state) |> fail?(:transaction_not_found) |> same?(state)
  end

  test "amounts must add up" do
    alice = ""
    bob = ""

    state = "alice deposited"

    # FIXME: dry and include more scenarios of possible invalid txs? use second input
    %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                 newowner1: bob, amount1: 6, newowner2: alice, amount2: 3, fee: 0}
    |> Core.exec(state) |> fail?(:amounts_dont_add_up) |> same?(state)
    %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                 newowner1: bob, amount1: 8, newowner2: alice, amount2: 3, fee: 0}
    |> Core.exec(state) |> fail?(:amounts_dont_add_up) |> same?(state)
    %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                 newowner1: bob, amount1: 7, newowner2: alice, amount2: 2, fee: 0}
    |> Core.exec(state) |> fail?(:amounts_dont_add_up) |> same?(state)
    %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                 newowner1: bob, amount1: 7, newowner2: alice, amount2: 4, fee: 0}
    |> Core.exec(state) |> fail?(:amounts_dont_add_up) |> same?(state)
    %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                 newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 1}
    |> Core.exec(state) |> fail?(:amounts_dont_add_up) |> same?(state)
    %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                 newowner1: bob, amount1: 7, newowner2: alice, amount2: 1, fee: 1}
    |> Core.exec(state) |> fail?(:amounts_dont_add_up) |> same?(state)

  end

  test "can't spend spent" do
    alice = "" # FIXME
    bob = ""

    state = "alice deposited"

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

    %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                 newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
    |> Core.exec(state) |> fail?(:output_spent)

  end

  test "can spend partially spent" do
    alice = "" # FIXME
    bob = ""
    carol = ""

    state = "alice deposited"

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

    state =
      %Transaction{blknum1: 0, txindex1: 1, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: carol, amount1: 7, newowner2: 0, amount2: 0, fee: 0}
      |> Core.exec(state) |> success?

    state =
      %Transaction{blknum1: 0, txindex1: 1, oindex1: 2, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: carol, amount1: 3, newowner2: 0, amount2: 0, fee: 0}
      |> Core.exec(state) |> success?

    %Transaction{blknum1: 0, txindex1: 2, oindex1: 0, blknum2: 0, txindex2: 3, oindex2: 0,
                 newowner1: alice, amount1: 10, newowner2: 0, amount2: 0, fee: 0}
    |> Core.exec(state) |> success?

  end

  test "can spend after block is formed" do
    alice = "" # FIXME
    bob = ""

    state = "alice deposited"

    {_, _, _, state} = Core.form_block(state)

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

    %Transaction{blknum1: 0, txindex1: 1, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                 newowner1: bob, amount1: 7, newowner2: 0, amount2: 0, fee: 0}
    |> Core.exec(state) |> success?
  end

  test "forming block doesn't unspend" do
    alice = "" # FIXME
    bob = ""

    state = "alice deposited"

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

    {_, _, _, state} = Core.form_block(state)

    %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                 newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
    |> Core.exec(state) |> fail?(:output_spent)

  end

  test "spending emits event trigger" do
    alice = "" # FIXME
    bob = ""

    state = "alice deposited"

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

    assert {_, [trigger], _, _} = Core.form_block(state)

    # FIXME: check
  end

  test "every spending emits event triggers" do
    alice = "" # FIXME
    bob = ""
    carol = ""

    state = "alice deposited"

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

    state =
      %Transaction{blknum1: 0, txindex1: 1, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: carol, amount1: 7, newowner2: 0, amount2: 0, fee: 0}
      |> Core.exec(state) |> success?

    assert {_, [_trigger1, _trigger2], _, _} = Core.form_block(state)
  end

  test "only successful spending emits event trigger" do
    alice = "" # FIXME
    bob = ""

    state = "empty"

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> fail?(:transaction_not_found) |> same?(state)

    assert {_, [], _, _} = Core.form_block(state)
  end

  test "deposits emit event triggers, they don't leak into next block" do
    alice = "" # FIXME

    state = "empty"

    assert {_, [trigger], _, state} = Core.deposit(alice, 4, state)

    # FIXME check

    assert {_, [], _, _} = Core.form_block(state)
  end

  test "empty blocks emit empty event triggers" do
    alice = "" # FIXME
    bob = ""

    state = "alice deposited"

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

    assert {_, [trigger], _, _} = Core.form_block(state)
    assert {_, [], _, _} = Core.form_block(state)
  end

  test "forming block puts all transactions in a block" do
    alice = "" # FIXME
    bob = ""
    carol = ""

    state = "alice deposited"

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

    state =
      %Transaction{blknum1: 0, txindex1: 1, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: carol, amount1: 7, newowner2: 0, amount2: 0, fee: 0}
      |> Core.exec(state) |> success?

    {block, _, _, _} = Core.form_block(state)

    # FIXME check block
  end

  test "forming block empty block after a non-empty block" do
    alice = "" # FIXME
    bob = ""

    state = "alice deposited"

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

    {_, _, _, state} = Core.form_block(state)
    {block, _, _, _} = Core.form_block(state)

    # FIXME check empty block
  end

  test "no pending transactions at start" do
    state = "empty state"

    {block, _, _, _} = Core.form_block(state)

    # FIXME check empty block
  end

  test "spending produces db updates" do
    alice = "" # FIXME
    bob = ""

    state = "alice deposited"

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

    {_, _, db_updates, _} = Core.form_block(state)

    # FIXME check new tx and block in db_updates
  end

  test "depositing produces db updates, that don't leak to next block" do
    alice = "" # FIXME

    state = "empty"

    {_, _, db_updates, state} = Core.deposit(alice, 4, state)

    # FIXME check block and transaction in db updates

    {_, _, [], _} = Core.form_block(state)
  end

  test "spending removes/adds utxos from db" do
    alice = "" # FIXME
    bob = ""

    state = "alice deposited"

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

    {_, _, db_updates, _} = Core.form_block(state)

    # FIXME check removal/add of utxos
  end

  test "empty blocks are pushed to db" do
    state = "empty"

    {_, _, db_updates, _} = Core.form_block(state)

    # FIXME empty block in db_udates and height bump
  end

  test "blocks with deposits and spends are pushed to db and events properly" do
    alice = "" # FIXME
    bob = ""

    state = "alice deposited"

    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?
    {deposit_block, [deposit_trigger], [deposit_db_update], state} = Core.deposit(alice, 4, state)

    {block, [spend_trigger], [spend_db_update], _} = Core.form_block(state)

    # FIXME check both ok in db and events and block
  end

  test "utxos get initialized by query result from db and are spendable" do
    alice = "" # FIXME
    bob = ""

    # TODO: use actual code to generate query result for utxos
    state = Core.extract_initial_state("utxo1, utxo2 etc")
    state =
      %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                   newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}
      |> Core.exec(state) |> success?

  end

  test "core generates the db query" do
    # NOTE: trivial test, considering current behavior, but might evolve... hm
    assert "correct query" == Core.get_state_fetching_query()
  end

  # TODO: other?

  defp do_deposit(state, owner, amount) do
    {_, _, _, new_state} =
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

  defp same?(state, expected_state) do
    assert expected_state == state
    state
  end
end
