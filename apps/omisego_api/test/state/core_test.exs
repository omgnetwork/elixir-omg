defmodule OmiseGO.API.State.CoreTest do
  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.Transaction


  test "can spend deposits" do
    alice = "" # FIXME
    bob = ""

    state =
      []
      |> Core.extract_initial_state()
      |> do_deposit(alice, 10)

    tx = %Transaction{blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
                      newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0}

    tx
    |> Core.exec(state)
    |> success?
  end

  test "can't spend nonexistent" do

  end

  test "amounts must sum up" do

  end

  test "can't spend spent" do

  end

  test "can spend partially spent" do

  end

  test "can spend after block is formed" do

  end

  test "forming block doesn't unspend" do

  end

  test "can split and consolidate coins" do

  end

  test "spending emits event trigger" do

  end

  test "every spending emits event triggers" do

  end

  test "only successful spending emits event trigger" do

  end

  test "deposits emit event triggers" do

  end

  test "empty blocks emit empty event triggers" do

  end

  test "forming block puts all transactions in a block" do

  end

  test "forming block empty block after a non-empty block" do

  end

  test "no pending transactions at start" do

  end

  test "spending produces db updates" do

  end

  test "depositing produces db updates" do

  end

  test "spending removes utxos from db" do

  end

  test "empty blocks are pushed to db" do

  end

  test "blocks with deposits and spends are pushed to db" do

  end

  test "utxos get initialized by query result from db" do

  end

  test "utxos from db are spendable" do

  end

  test "core generates the db query" do
    # NOTE: trivial test, considering current behavior, but might evolve... hm
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
end
