defmodule OmiseGOWatcherWeb.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use Plug.Test

  alias OmiseGOWatcher.TransactionDB
  alias OmiseGO.API.State.{Transaction, Transaction.Signed}
  alias OmiseGO.API.{Block}

  @moduletag :watcher_tests

  @empty_signed_tx %Signed{
    raw_tx: %Transaction{
      blknum1: 0,
      txindex1: 0,
      oindex1: 0,
      blknum2: 0,
      txindex2: 0,
      oindex2: 0,
      newowner1: "",
      amount1: 0,
      newowner2: "",
      amount2: 0,
      fee: 0
    }
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OmiseGOWatcher.Repo)
  end

  test "insert and retrive transaction" do
    txblknum = 0
    txindex = 0

    {:ok, %TransactionDB{id: id}} = TransactionDB.insert(@empty_signed_tx, txblknum, txindex)
    actual_transaction = TransactionDB.get(id)

    expected_transaction_2 = expected_transaction(txblknum, txindex)

    assert expected_transaction = actual_transaction
  end

  test "insert and retrive block of transactions " do
    txblknum = 0

    [{:ok, %TransactionDB{id: tx_id_1}}, {:ok, %TransactionDB{id: tx_id_2}}] =
      TransactionDB.insert(
        %Block{
          transactions: [
            @empty_signed_tx,
            @empty_signed_tx
          ]
        },
        txblknum
      )

    actual_transaction_1 = TransactionDB.get(tx_id_1)
    actual_transaction_2 = TransactionDB.get(tx_id_2)

    expected_transaction_2 = expected_transaction(txblknum, 0)
    expected_transaction_2 = expected_transaction(txblknum, 1)

    assert expected_transaction_1 = actual_transaction_1
    assert expected_transaction_2 = actual_transaction_2
  end

  defp expected_transaction(txblknum, txindex) do
    @empty_signed_tx.raw_tx
    |> (&Map.merge(
          %TransactionDB{
            txblknum: txblknum,
            txindex: txindex
          },
          &1
        )).()
  end
end
